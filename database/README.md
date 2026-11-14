# MediQueue Database

MySQL 8.0+ schema for MediQueue. The kiosk booking part matches the SRS dated 26 Oct 2026
(patient identification, clinic selection, available times, booking). On top of that it
has the proposal's staff accounts, doctors, check-in and queue tickets, and clinical
records; see [Staff, queue and clinical records](#staff-queue-and-clinical-records).

## Setup

```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
```

The app connects as `mq_kiosk` (created in `schema.sql`). It can read data and insert
bookings, but cannot update or delete anything (NFR-05, NFR-07). Change its password
before the demo and keep the real one out of Git.

## Tables

```
patient (1) ──< appointment >── (1) appointment_slot >── (1) clinic
```

| Table | Purpose | Key rules |
|---|---|---|
| `patient` | Simulated patients, looked up by national ID | `national_id` unique, 10 digits starting with 1 or 2 |
| `clinic` | Outpatient clinics on the kiosk | `name` unique; `is_active = FALSE` hides it |
| `appointment_slot` | Bookable times per clinic | One slot per clinic per start time |
| `appointment` | A patient's booking of a slot | At most one `BOOKED` row per slot |

Views:

- `available_slot`: future, unbooked slots of active clinics (FR-05, FR-10).
- `booking_confirmation`: data for the confirmation screen, with a reference like `MQ-000042` (FR-09).

## Requirement mapping

| Requirement | Where it's enforced |
|---|---|
| FR-01, FR-02, NFR-04 | `patient.national_id` lookup + format check |
| FR-03, FR-04 | `clinic WHERE is_active` |
| FR-05, FR-10 | `available_slot` view |
| FR-07, FR-09 | `INSERT INTO appointment`, then `booking_confirmation` |
| FR-08, FR-11, NFR-03, NFR-08, NFR-10 | Unique index `uq_appointment_active_slot` |
| NFR-05, NFR-07 | `mq_kiosk` user privileges |
| NFR-06 | `seed.sql` uses obviously fake data |
| NFR-11 | InnoDB tables (durable after restart) |

## Queries for the DAO layer

```sql
-- Identify patient (FR-01)
SELECT patient_id, full_name FROM patient WHERE national_id = ?;

-- List clinics (FR-03)
SELECT clinic_id, name, location FROM clinic WHERE is_active = TRUE ORDER BY name;

-- Available times (FR-05); empty result -> FR-10 message
SELECT slot_id, start_time, end_time FROM available_slot
WHERE clinic_id = ? ORDER BY start_time;

-- Book (FR-07)
INSERT INTO appointment (slot_id, patient_id) VALUES (?, ?);

-- Confirmation (FR-09)
SELECT * FROM booking_confirmation WHERE appointment_id = ?;
```

## How double booking is prevented

Don't check availability with a `SELECT` and then `INSERT`: two kiosks can both pass the
check before either inserts. Just insert. The unique index on `active_slot_id` lets only
one insert win; the other gets MySQL error **1062**, which the DAO turns into the FR-11
"this time is no longer available" message.

```java
public int book(int slotId, int patientId) throws SlotTakenException, SQLException {
    String sql = "INSERT INTO appointment (slot_id, patient_id) VALUES (?, ?)";
    try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
        ps.setInt(1, slotId);
        ps.setInt(2, patientId);
        ps.executeUpdate();
        try (ResultSet keys = ps.getGeneratedKeys()) {
            keys.next();
            return keys.getInt(1);   // appointment_id for the confirmation screen
        }
    } catch (SQLIntegrityConstraintViolationException e) {
        if (e.getErrorCode() == 1062) throw new SlotTakenException(slotId);  // FR-11
        throw e;
    }
}
```

`active_slot_id` is a generated column (`slot_id` while `BOOKED`, `NULL` once `CANCELLED`),
so a cancelled slot becomes bookable again without deleting history.

## Staff, queue and clinical records

These come from the proposal and go beyond the current SRS scope. The kiosk's tables and
views above are unchanged, so the existing kiosk code keeps working.

```
staff (1) ──(0..1) doctor >── clinic
doctor (1) ──< appointment_slot
patient (1) ──< queue_ticket >── clinic        appointment (1) ──(0..1) queue_ticket
queue_ticket (1) ──< vital_signs
queue_ticket (1) ──(0..1) consultation (1) ──< prescription
```

| Table | Purpose | Key rules |
|---|---|---|
| `staff` | Login accounts: admin, receptionist, nurse, doctor, pharmacist | `username` unique; PBKDF2 password hash, never plain text |
| `doctor` | Staff who see patients, one clinic each | A slot's doctor must work in that slot's clinic |
| `queue_ticket` | One visit in a clinic's queue for one day; the ticket is the check-in | Numbers like `EMG-001`, unique per day; a booking can be checked in once |
| `ticket_counter` | Last ticket number per day and type | Used only by `issue_ticket` |
| `vital_signs` | Blood pressure, pulse and temperature from the nurse | Impossible values (typing mistakes) are rejected |
| `consultation` | The doctor's diagnosis and notes | One per ticket |
| `prescription` | One medicine per row | `DISPENSED` needs the pharmacist and the time |

Clinical records hang off the ticket, not the booking, so emergency patients need no booking.

### Procedures

- `issue_ticket(type, patient_id, clinic_id, appointment_id, staff_id, OUT ticket_no)` is
  the only way to create a ticket.
  - `APPOINTMENT`: pass the `appointment_id`. The booking must be `BOOKED` and for today.
  - `EMERGENCY`, `SENIOR` or `WALK_IN`: pass `patient_id` and `clinic_id`, and the
    receptionist's `staff_id` (or `NULL` at the kiosk).
  - Prefixes: `EMG`, `SNR`, `APT`, `WLK`. Many kiosks can issue tickets at once without
    duplicate numbers.
  - Errors (SQLSTATE `45000`): "No booking for today with this reference",
    "This booking is already checked in", "Unknown ticket type".
- `check_in(appointment_id, OUT ticket_no)` is what the kiosk calls. It issues an
  `APPOINTMENT` ticket only, so patients can't print priority tickets; `EMERGENCY` and
  `SENIOR` tickets come from staff through `issue_ticket`.
- `call_next(clinic_id, doctor_id, OUT ticket_no)` marks the next waiting ticket `CALLED`
  and returns its number, or `NULL` if nobody is waiting. Order: emergency, senior,
  appointment, walk-in, then first come. Two doctors calling at once get different patients.

Kiosk check-in from Java:

```java
try (CallableStatement cs = conn.prepareCall("{CALL check_in(?, ?)}")) {
    cs.setInt(1, appointmentId);
    cs.registerOutParameter(2, Types.VARCHAR);
    cs.execute();
    String ticketNo = cs.getString(2);     // e.g. "APT-003"
} // SQLException with SQLState "45000": show e.getMessage() to the patient
```

Two kiosks checking in the same booking at the same instant: one gets the ticket, the
other gets error 1062 instead of the 45000 message; treat it as "already checked in".

### Views

- `doctor_schedule`: each doctor's slots and who booked them.
- `queue_board`: today's waiting patients per clinic in calling order (`position`), with
  the latest vital signs.
- `hall_display`: called tickets and their rooms for the waiting-hall screen, without
  patient names.
- `pharmacy_queue`: prescriptions waiting to be dispensed.

### Accounts

| MySQL user | Used by | Can |
|---|---|---|
| `mq_kiosk` | Kiosk app | Read patients, clinics and slots; book; check in through `check_in`; read `hall_display`. Cannot issue priority tickets, read staff or clinical data, or update or delete anything. |
| `mq_staff` | Staff app | Read everything; add vitals, consultations and prescriptions; dispense; manage staff, clinics and slots; call `issue_ticket` and `call_next`. Cannot delete anything or edit a consultation. |

The staff app checks `staff.role` before each action; the database account is shared.
Both passwords in `schema.sql` are placeholders: change them on the demo laptop with
`ALTER USER`, not in the repo.

### Staff login

Demo accounts (all in `seed.sql`): `admin`, `reception1`, `nurse1`, `nurse2`,
`dr.general`, `dr.peds`, `dr.eye`, `dr.derm`, `pharma1`.
**Demo only:** they all use the password `MediQueue-Demo-2026`, which is public on GitHub.

To check a login, hash the typed password with the row's salt and iteration count and
compare (standard Java, no library needed):

```java
static boolean verify(String typed, String hashHex, String saltHex, int iter) throws Exception {
    PBEKeySpec spec = new PBEKeySpec(typed.toCharArray(), HexFormat.of().parseHex(saltHex), iter, 256);
    byte[] actual = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
    return MessageDigest.isEqual(actual, HexFormat.of().parseHex(hashHex));
}
// SELECT staff_id, role, password_hash, password_salt, password_iter
// FROM staff WHERE username = ? AND is_active = TRUE
```

To create a new account, generate a random 16-byte salt, hash with 600000 iterations, and
store the hex values in `password_hash` and `password_salt`.

### Demo data

`seed.sql` also creates a queue for the day you load it: two booked patients checked in
(`APT-001`, `APT-002`), a senior walk-in (`SNR-001`) and an emergency (`EMG-001`). The
emergency has already been called, seen and given two prescriptions, one dispensed.

### Not included yet

Referrals between clinics, a medicine catalogue, reports, and a rule that moves long-waiting
walk-ins up the queue.
