# MediQueue Database

MySQL 8.0+ schema for the kiosk booking prototype, matching the SRS dated 26 Oct 2026
(patient identification, clinic selection, available times, booking).

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

## Extending later

The proposal's queue, nurse, doctor and pharmacy features are out of scope in the current
SRS. If they come back, they'd add tables such as `ticket`, `vital_signs`, `staff` and
`prescription` that reference `patient` and `appointment`; nothing here needs to change.
