# MediQueue Database Update v2

**Author:** Ahmed Ali Al Jader (database)
**Date:** 14 November 2026
**Files changed:** `database/schema.sql`, `database/seed.sql`, `database/README.md`

The database now supports the full hospital flow from the proposal: staff logins, doctors and their schedules, check-in with queue tickets, and clinical records. It grew from 4 tables to 11. The tables and views the kiosk app already uses are unchanged, so the current kiosk code keeps working without edits.

---

## What's new

### 1. Staff accounts and roles
- **`staff` table:** login accounts with five roles: Admin, Receptionist, Nurse, Doctor, Pharmacist.
- **Passwords:** stored as PBKDF2-SHA256 hashes with a random salt, never as plain text. Java can check them with its built-in libraries, so no new dependency is needed.
- **Inactive accounts:** an account can be switched off (`is_active`) without deleting it.

### 2. Doctors and schedules
- **`doctor` table:** each doctor works in one clinic and has a specialty.
- **Slots:** each appointment slot is now assigned to a doctor.
- **Same-clinic rule:** the database rejects a slot assigned to a doctor from a different clinic.
- **No double-booking doctors:** a doctor can't have two slots at the same time.
- **`doctor_schedule` view:** each doctor's slots and who booked them.

### 3. Check-in and queue tickets
- **`queue_ticket` table:** one row per patient visit per day. The ticket is the check-in.
- **Ticket numbers:**

  | Type | Example | Issued by |
  |---|---|---|
  | Emergency | `EMG-001` | Emergency intake (staff) |
  | Senior | `SNR-001` | Assisted desk (receptionist) |
  | Appointment | `APT-001` | Kiosk check-in |
  | Walk-in | `WLK-001` | Reception |

- **Unique numbers:** ticket numbers stay unique even when many kiosks issue tickets at the same moment. This was a named risk in the proposal ("Concurrency Control in Queue Numbers").
- **Calling order:** doctors call patients emergency first, then senior, then appointment, then walk-in. Within each group it's first come, first served.
- **Doctors calling together:** if two doctors press "call next" at the same moment, each gets a different patient.
- **Check-in rules:** a booking can be checked in only once, and only on its own day. A cancelled booking can't be checked in.

**New procedures:**

| Procedure | Who uses it | What it does |
|---|---|---|
| `check_in(appointment_id)` | Kiosk | Checks in a booking and returns an `APT-…` ticket |
| `issue_ticket(type, patient, clinic, appointment, staff)` | Staff | Issues any ticket type, including emergency and senior |
| `call_next(clinic, doctor)` | Doctor | Calls the next patient and returns the ticket number |

**New views:**
- **`queue_board`:** each clinic's waiting patients in order, with their latest vital signs.
- **`hall_display`:** called tickets and rooms for the waiting-hall screen, with no patient names.

### 4. Clinical records
- **`vital_signs`:** blood pressure, pulse and temperature recorded by the nurse. Impossible values are rejected, for example systolic lower than diastolic, or a temperature of 73 °C.
- **`consultation`:** the doctor's diagnosis and notes, one per visit.
- **`prescription`:** one medicine per row, with dosage, frequency and duration. A prescription can only be marked dispensed when the pharmacist and the time are recorded.
- **`pharmacy_queue` view:** prescriptions waiting to be dispensed.
- **Emergency patients:** records are linked to the queue ticket, not the booking, so emergency patients don't need a booking.

### 5. Database accounts

| Account | Used by | Allowed | Blocked |
|---|---|---|---|
| `mq_kiosk` | Kiosk app | Read clinics and slots, book, check in, read the hall display | Priority tickets, staff data, medical records, any edit or delete |
| `mq_staff` *(new)* | Staff app | Read everything, add vitals, consultations and prescriptions, dispense, call patients, manage staff and slots | Deleting records, editing a finished consultation |

Both passwords in `schema.sql` are placeholders. Change them on the demo laptop, not in the repo.

### 6. Demo data
`seed.sql` now also creates:
- **9 demo staff accounts:** `admin`, `reception1`, `nurse1`, `nurse2`, `dr.general`, `dr.peds`, `dr.eye`, `dr.derm` and `pharma1`.
  - All of them use the password `MediQueue-Demo-2026`. It's public on GitHub, so it's for the demo only.
- **Slots for 15 days, starting today,** so the kiosk also offers same-day times.
- **A live queue for the day you load it:**
  - two booked patients checked in (`APT-001`, `APT-002`)
  - a senior walk-in (`SNR-001`)
  - an emergency (`EMG-001`) that has already been called, seen and given two prescriptions, one of them dispensed

---

## Test results

All tests passed on MySQL 8.0.45.

| Test | Result |
|---|---|
| Kiosk views have exactly the same columns as before | PASS |
| Booking a taken slot is rejected | PASS |
| Two kiosks booking the same slot at once: only one succeeds | PASS |
| Cancel, then rebook the same slot | PASS |
| Invalid national ID is rejected | PASS |
| 20 tickets issued at the same moment get 20 unique numbers | PASS |
| Same booking checked in twice is rejected | PASS |
| Two kiosks checking in the same booking at once: one ticket only | PASS |
| Tomorrow's booking can't be checked in today | PASS |
| Cancelled booking can't be checked in | PASS |
| 5 doctors calling at once each get a different patient, emergency first | PASS |
| Calling with nobody waiting returns nothing | PASS |
| Impossible vital signs are rejected | PASS |
| Slot assigned to a doctor from another clinic is rejected | PASS |
| Marking a prescription dispensed without a pharmacist is rejected | PASS |
| Kiosk can't issue an emergency ticket | PASS |
| Kiosk can't read staff passwords or medical records | PASS |
| Staff account can't delete records or edit a finished consultation | PASS |
| Java verifies the demo staff passwords correctly | PASS |
| Java kiosk check-in works with the team's MySQL driver | PASS |

---

## What the team needs to do

1. **Reload the database** after pulling: run `setup.bat` and answer **Y**, or run `schema.sql` then `seed.sql`. This replaces your current test data.
2. **Kiosk team:** add a check-in screen. The Java code is in `database/README.md` under *Procedures*.
3. **Staff app (new):** login, nurse, doctor and pharmacy screens using the `mq_staff` account. The login code is in `database/README.md` under *Staff login*.
4. **SRS / SDD:** the SRS lists these features as out of scope. If we keep them, both documents need updating. The SDD needs the new table diagram.

## Not included yet
- Referrals between clinics
- A medicine catalogue
- Reports and statistics
- A rule that moves long-waiting walk-ins up the queue

Database questions: Ahmed Ali Al Jader.
