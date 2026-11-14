-- =====================================================================
-- MediQueue - Database Schema (MySQL 8.0+)
-- Kiosk booking, per SRS (26 Oct 2026)
--   FR-01..FR-02  patient identification   -> patient
--   FR-03..FR-04  clinic selection         -> clinic
--   FR-05, FR-10  available times          -> appointment_slot + available_slot view
--   FR-06..FR-09, FR-11  booking           -> appointment
--   FR-08, NFR-03, NFR-08  no double booking -> uq_appointment_active_slot
-- Extensions from the proposal (beyond the current SRS scope)
--   staff accounts and roles  -> staff, doctor
--   check-in and queue        -> queue_ticket, ticket_counter, issue_ticket, check_in, call_next
--   clinical records          -> vital_signs, consultation, prescription
-- =====================================================================

DROP DATABASE IF EXISTS mediqueue;
CREATE DATABASE mediqueue
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE mediqueue;

-- ---------------------------------------------------------------------
-- patient: simulated patient records (NFR-06). The kiosk looks patients
-- up by national ID; it does not create them.
-- ---------------------------------------------------------------------
CREATE TABLE patient (
  patient_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  national_id    CHAR(10)      NOT NULL,
  full_name      VARCHAR(100)  NOT NULL,
  date_of_birth  DATE          NOT NULL,
  gender         ENUM('M','F') NOT NULL,
  phone          VARCHAR(15)   NULL,
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (patient_id),
  CONSTRAINT uq_patient_national_id UNIQUE (national_id),
  -- Saudi national IDs (1...) and iqama numbers (2...) are 10 digits
  CONSTRAINT chk_patient_national_id CHECK (national_id REGEXP '^[12][0-9]{9}$')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- clinic: outpatient clinics shown on the kiosk (FR-03)
-- ---------------------------------------------------------------------
CREATE TABLE clinic (
  clinic_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name       VARCHAR(60)       NOT NULL,
  location   VARCHAR(60)       NOT NULL,   -- e.g. 'Building A, Floor 1, Room 104'
  is_active  BOOLEAN           NOT NULL DEFAULT TRUE,
  PRIMARY KEY (clinic_id),
  CONSTRAINT uq_clinic_name UNIQUE (name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- staff: login accounts for hospital staff. role drives what the app
-- lets each person do. Passwords are PBKDF2-HMAC-SHA256 hashes, never
-- plain text: the app hashes the typed password with the stored salt and
-- iteration count and compares it with password_hash.
-- ---------------------------------------------------------------------
CREATE TABLE staff (
  staff_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  username       VARCHAR(30)   NOT NULL,
  full_name      VARCHAR(100)  NOT NULL,
  role           ENUM('ADMIN','RECEPTIONIST','NURSE','DOCTOR','PHARMACIST') NOT NULL,
  password_hash  CHAR(64)      NOT NULL,   -- hex, 32 bytes
  password_salt  CHAR(32)      NOT NULL,   -- hex, 16 bytes
  password_iter  INT UNSIGNED  NOT NULL,
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (staff_id),
  CONSTRAINT uq_staff_username UNIQUE (username)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- doctor: staff members who see patients, each in one clinic
-- ---------------------------------------------------------------------
CREATE TABLE doctor (
  staff_id   INT UNSIGNED      NOT NULL,
  clinic_id  SMALLINT UNSIGNED NOT NULL,
  specialty  VARCHAR(60)       NOT NULL,
  PRIMARY KEY (staff_id),
  -- target of the slot's (doctor_id, clinic_id) foreign key
  CONSTRAINT uq_doctor_clinic UNIQUE (staff_id, clinic_id),
  CONSTRAINT fk_doctor_staff FOREIGN KEY (staff_id)
    REFERENCES staff (staff_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_doctor_clinic FOREIGN KEY (clinic_id)
    REFERENCES clinic (clinic_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- appointment_slot: bookable times per clinic (glossary: "Appointment Slot")
-- The doctor is optional; when set, the composite key makes sure the
-- doctor works in the same clinic as the slot.
-- ---------------------------------------------------------------------
CREATE TABLE appointment_slot (
  slot_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  clinic_id   SMALLINT UNSIGNED NOT NULL,
  doctor_id   INT UNSIGNED      NULL,
  start_time  DATETIME          NOT NULL,
  end_time    DATETIME          NOT NULL,
  PRIMARY KEY (slot_id),
  CONSTRAINT uq_slot_clinic_start UNIQUE (clinic_id, start_time),
  CONSTRAINT uq_slot_doctor_start UNIQUE (doctor_id, start_time),
  CONSTRAINT chk_slot_times CHECK (end_time > start_time),
  CONSTRAINT fk_slot_clinic FOREIGN KEY (clinic_id)
    REFERENCES clinic (clinic_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_slot_doctor FOREIGN KEY (doctor_id, clinic_id)
    REFERENCES doctor (staff_id, clinic_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- appointment: a booking of one slot by one patient (FR-07)
--
-- Double-booking guard: active_slot_id equals slot_id while the booking is
-- BOOKED and NULL once CANCELLED. A UNIQUE index ignores NULLs, so a slot
-- can hold at most one active booking but can be rebooked after a
-- cancellation. Two kiosks inserting the same slot at once: the second
-- INSERT fails with error 1062 (duplicate key), which the DAO maps to the
-- FR-11 "time no longer available" message.
-- ---------------------------------------------------------------------
CREATE TABLE appointment (
  appointment_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  slot_id         INT UNSIGNED  NOT NULL,
  patient_id      INT UNSIGNED  NOT NULL,
  status          ENUM('BOOKED','CANCELLED') NOT NULL DEFAULT 'BOOKED',
  booked_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  active_slot_id  INT UNSIGNED
    AS (IF(status = 'BOOKED', slot_id, NULL)) STORED,
  PRIMARY KEY (appointment_id),
  CONSTRAINT uq_appointment_active_slot UNIQUE (active_slot_id),
  -- No CASCADE here: MySQL forbids it on the base column of a stored
  -- generated column (slot_id feeds active_slot_id).
  CONSTRAINT fk_appointment_slot FOREIGN KEY (slot_id)
    REFERENCES appointment_slot (slot_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id)
    REFERENCES patient (patient_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX idx_appointment_patient (patient_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- available_slot: future slots of active clinics with no active booking
-- (FR-05). An empty result for a clinic drives the FR-10 message.
-- ---------------------------------------------------------------------
CREATE VIEW available_slot AS
SELECT s.slot_id, s.clinic_id, c.name AS clinic_name, c.location,
       s.start_time, s.end_time
FROM appointment_slot s
JOIN clinic c ON c.clinic_id = s.clinic_id
LEFT JOIN appointment a ON a.active_slot_id = s.slot_id
WHERE c.is_active = TRUE
  AND s.start_time > NOW()
  AND a.appointment_id IS NULL;

-- ---------------------------------------------------------------------
-- booking_confirmation: everything the confirmation screen shows (FR-09)
-- ---------------------------------------------------------------------
CREATE VIEW booking_confirmation AS
SELECT a.appointment_id,
       CONCAT('MQ-', LPAD(a.appointment_id, 6, '0')) AS reference_no,
       a.status, a.booked_at,
       p.national_id, p.full_name,
       c.name AS clinic_name, c.location,
       s.start_time, s.end_time
FROM appointment a
JOIN patient p          ON p.patient_id = a.patient_id
JOIN appointment_slot s ON s.slot_id    = a.slot_id
JOIN clinic c           ON c.clinic_id  = s.clinic_id;

-- ---------------------------------------------------------------------
-- queue_ticket: one visit in a clinic's queue for one day. A ticket is
-- the check-in: APPOINTMENT tickets point at the booking, the others are
-- walk-ins issued at the assisted desk (SENIOR) or emergency intake.
-- Clinical records hang off the ticket, so emergencies need no booking.
-- Always create tickets through issue_ticket, which numbers them.
-- ---------------------------------------------------------------------
CREATE TABLE queue_ticket (
  ticket_id       INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  queue_date      DATE              NOT NULL,
  ticket_type     ENUM('EMERGENCY','SENIOR','APPOINTMENT','WALK_IN') NOT NULL,
  seq             SMALLINT UNSIGNED NOT NULL,
  ticket_no       VARCHAR(10)       NOT NULL,   -- e.g. EMG-001, SNR-004
  patient_id      INT UNSIGNED      NOT NULL,
  clinic_id       SMALLINT UNSIGNED NOT NULL,
  appointment_id  INT UNSIGNED      NULL,
  status          ENUM('WAITING','CALLED','DONE','NO_SHOW') NOT NULL DEFAULT 'WAITING',
  issued_by       INT UNSIGNED      NULL,       -- NULL when the patient used the kiosk
  called_by       INT UNSIGNED      NULL,
  issued_at       DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  called_at       DATETIME          NULL,
  PRIMARY KEY (ticket_id),
  CONSTRAINT uq_ticket_seq UNIQUE (queue_date, ticket_type, seq),
  CONSTRAINT uq_ticket_no UNIQUE (queue_date, ticket_no),
  CONSTRAINT uq_ticket_appointment UNIQUE (appointment_id),   -- check in once
  CONSTRAINT chk_ticket_appointment
    CHECK ((ticket_type = 'APPOINTMENT') = (appointment_id IS NOT NULL)),
  CONSTRAINT fk_ticket_patient FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
  CONSTRAINT fk_ticket_clinic FOREIGN KEY (clinic_id) REFERENCES clinic (clinic_id),
  CONSTRAINT fk_ticket_appointment FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id),
  CONSTRAINT fk_ticket_issued_by FOREIGN KEY (issued_by) REFERENCES staff (staff_id),
  CONSTRAINT fk_ticket_called_by FOREIGN KEY (called_by) REFERENCES doctor (staff_id),
  INDEX idx_ticket_queue (clinic_id, queue_date, status)
) ENGINE = InnoDB;

-- ticket_counter: last number handed out per day and ticket type
CREATE TABLE ticket_counter (
  queue_date   DATE              NOT NULL,
  ticket_type  ENUM('EMERGENCY','SENIOR','APPOINTMENT','WALK_IN') NOT NULL,
  last_seq     SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (queue_date, ticket_type)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- vital_signs: measured by the nurse before the doctor calls the patient
-- ---------------------------------------------------------------------
CREATE TABLE vital_signs (
  vital_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  ticket_id    INT UNSIGNED      NOT NULL,
  nurse_id     INT UNSIGNED      NOT NULL,
  systolic     SMALLINT UNSIGNED NOT NULL,   -- mmHg
  diastolic    SMALLINT UNSIGNED NOT NULL,   -- mmHg
  pulse        SMALLINT UNSIGNED NOT NULL,   -- beats per minute
  temperature  DECIMAL(3,1)      NOT NULL,   -- degrees Celsius
  recorded_at  DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (vital_id),
  -- reject typing mistakes, not clinical extremes
  CONSTRAINT chk_vital_bp CHECK (systolic BETWEEN 50 AND 260
                             AND diastolic BETWEEN 30 AND 160
                             AND systolic > diastolic),
  CONSTRAINT chk_vital_pulse CHECK (pulse BETWEEN 20 AND 250),
  CONSTRAINT chk_vital_temp CHECK (temperature BETWEEN 30.0 AND 45.0),
  CONSTRAINT fk_vital_ticket FOREIGN KEY (ticket_id) REFERENCES queue_ticket (ticket_id),
  CONSTRAINT fk_vital_nurse FOREIGN KEY (nurse_id) REFERENCES staff (staff_id),
  INDEX idx_vital_ticket (ticket_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- consultation: the doctor's record of one visit
-- ---------------------------------------------------------------------
CREATE TABLE consultation (
  consultation_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  ticket_id        INT UNSIGNED  NOT NULL,
  doctor_id        INT UNSIGNED  NOT NULL,
  diagnosis        VARCHAR(200)  NOT NULL,
  notes            TEXT          NULL,
  created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (consultation_id),
  CONSTRAINT uq_consultation_ticket UNIQUE (ticket_id),
  CONSTRAINT fk_consultation_ticket FOREIGN KEY (ticket_id) REFERENCES queue_ticket (ticket_id),
  CONSTRAINT fk_consultation_doctor FOREIGN KEY (doctor_id) REFERENCES doctor (staff_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- prescription: one medicine per row; the pharmacy marks it dispensed
-- ---------------------------------------------------------------------
CREATE TABLE prescription (
  prescription_id  INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  consultation_id  INT UNSIGNED      NOT NULL,
  medication       VARCHAR(100)      NOT NULL,
  dosage           VARCHAR(50)       NOT NULL,   -- e.g. '500 mg'
  frequency        VARCHAR(50)       NOT NULL,   -- e.g. 'every 8 hours'
  duration_days    SMALLINT UNSIGNED NOT NULL,
  status           ENUM('PENDING','DISPENSED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  dispensed_by     INT UNSIGNED      NULL,
  dispensed_at     DATETIME          NULL,
  PRIMARY KEY (prescription_id),
  CONSTRAINT chk_prescription_days CHECK (duration_days BETWEEN 1 AND 365),
  CONSTRAINT chk_prescription_dispensed
    CHECK ((status = 'DISPENSED') = (dispensed_by IS NOT NULL AND dispensed_at IS NOT NULL)),
  CONSTRAINT fk_prescription_consultation FOREIGN KEY (consultation_id)
    REFERENCES consultation (consultation_id),
  CONSTRAINT fk_prescription_pharmacist FOREIGN KEY (dispensed_by) REFERENCES staff (staff_id),
  INDEX idx_prescription_status (status)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- issue_ticket: the only way to create a ticket.
--   APPOINTMENT: pass p_appointment_id; patient and clinic come from the
--     booking, which must be BOOKED and for today.
--   EMERGENCY / SENIOR / WALK_IN: pass p_patient_id and p_clinic_id.
-- Numbers are safe with many kiosks at once: the counter row is updated
-- under a row lock, and LAST_INSERT_ID(expr) returns this session's value.
-- ---------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE issue_ticket(
  IN  p_type            VARCHAR(12),
  IN  p_patient_id      INT UNSIGNED,
  IN  p_clinic_id       SMALLINT UNSIGNED,
  IN  p_appointment_id  INT UNSIGNED,
  IN  p_staff_id        INT UNSIGNED,
  OUT p_ticket_no       VARCHAR(10))
BEGIN
  DECLARE v_patient INT UNSIGNED DEFAULT NULL;
  DECLARE v_clinic  SMALLINT UNSIGNED DEFAULT NULL;
  DECLARE v_seq     INT UNSIGNED;

  IF p_type = 'APPOINTMENT' THEN
    SELECT a.patient_id, s.clinic_id INTO v_patient, v_clinic
    FROM appointment a
    JOIN appointment_slot s ON s.slot_id = a.slot_id
    WHERE a.appointment_id = p_appointment_id
      AND a.status = 'BOOKED'
      AND DATE(s.start_time) = CURDATE();
    IF v_patient IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No booking for today with this reference';
    END IF;
    IF EXISTS (SELECT 1 FROM queue_ticket WHERE appointment_id = p_appointment_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This booking is already checked in';
    END IF;
  ELSEIF p_type IN ('EMERGENCY','SENIOR','WALK_IN') THEN
    SET v_patient = p_patient_id, v_clinic = p_clinic_id, p_appointment_id = NULL;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown ticket type';
  END IF;

  INSERT INTO ticket_counter (queue_date, ticket_type, last_seq)
  VALUES (CURDATE(), p_type, LAST_INSERT_ID(1))
  ON DUPLICATE KEY UPDATE last_seq = LAST_INSERT_ID(last_seq + 1);
  SET v_seq = LAST_INSERT_ID();

  SET p_ticket_no = CONCAT(
    ELT(FIELD(p_type, 'EMERGENCY','SENIOR','APPOINTMENT','WALK_IN'), 'EMG','SNR','APT','WLK'),
    '-', IF(v_seq < 1000, LPAD(v_seq, 3, '0'), v_seq));

  INSERT INTO queue_ticket
    (queue_date, ticket_type, seq, ticket_no, patient_id, clinic_id, appointment_id, issued_by)
  VALUES
    (CURDATE(), p_type, v_seq, p_ticket_no, v_patient, v_clinic, p_appointment_id, p_staff_id);
END //

-- check_in: the kiosk's only way in, so a patient cannot print
-- EMERGENCY or SENIOR tickets; those come from staff via issue_ticket.
CREATE PROCEDURE check_in(
  IN  p_appointment_id  INT UNSIGNED,
  OUT p_ticket_no       VARCHAR(10))
BEGIN
  CALL issue_ticket('APPOINTMENT', NULL, NULL, p_appointment_id, NULL, p_ticket_no);
END //

-- ---------------------------------------------------------------------
-- call_next: the doctor takes the next waiting patient in the clinic.
-- Order: emergency, senior, appointment, walk-in; then first come.
-- Two doctors calling at once: the second waits for the first to commit,
-- then gets the next ticket. (SKIP LOCKED would wrongly report an empty
-- queue, because the sorted read locks every waiting row.)
-- Returns NULL in p_ticket_no when nobody is waiting.
-- ---------------------------------------------------------------------
CREATE PROCEDURE call_next(
  IN  p_clinic_id  SMALLINT UNSIGNED,
  IN  p_doctor_id  INT UNSIGNED,
  OUT p_ticket_no  VARCHAR(10))
BEGIN
  DECLARE v_ticket INT UNSIGNED DEFAULT NULL;
  START TRANSACTION;
  -- shortcut: strict priority can starve walk-ins on busy days; add an
  -- aging rule (e.g. promote anyone waiting over 60 minutes) if that happens.
  SELECT ticket_id, ticket_no INTO v_ticket, p_ticket_no
  FROM queue_ticket
  WHERE clinic_id = p_clinic_id AND queue_date = CURDATE() AND status = 'WAITING'
  ORDER BY FIELD(ticket_type, 'EMERGENCY','SENIOR','APPOINTMENT','WALK_IN'), issued_at, ticket_id
  LIMIT 1
  FOR UPDATE;
  IF v_ticket IS NOT NULL THEN
    UPDATE queue_ticket
    SET status = 'CALLED', called_by = p_doctor_id, called_at = NOW()
    WHERE ticket_id = v_ticket;
  END IF;
  COMMIT;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- doctor_schedule: each doctor's slots and who booked them
-- ---------------------------------------------------------------------
CREATE VIEW doctor_schedule AS
SELECT s.slot_id, s.doctor_id, st.full_name AS doctor_name, d.specialty,
       c.clinic_id, c.name AS clinic_name, s.start_time, s.end_time,
       a.appointment_id, p.full_name AS patient_name
FROM appointment_slot s
JOIN doctor d  ON d.staff_id   = s.doctor_id
JOIN staff st  ON st.staff_id  = d.staff_id
JOIN clinic c  ON c.clinic_id  = s.clinic_id
LEFT JOIN appointment a ON a.active_slot_id = s.slot_id
LEFT JOIN patient p     ON p.patient_id     = a.patient_id;

-- ---------------------------------------------------------------------
-- queue_board: today's waiting patients per clinic, in calling order,
-- with the latest vital signs the nurse recorded
-- ---------------------------------------------------------------------
CREATE VIEW queue_board AS
SELECT t.ticket_id, t.ticket_no, t.ticket_type, t.clinic_id, c.name AS clinic_name,
       ROW_NUMBER() OVER (PARTITION BY t.clinic_id
         ORDER BY FIELD(t.ticket_type, 'EMERGENCY','SENIOR','APPOINTMENT','WALK_IN'),
                  t.issued_at, t.ticket_id) AS position,
       p.full_name AS patient_name, t.issued_at,
       v.systolic, v.diastolic, v.pulse, v.temperature, v.recorded_at AS vitals_at
FROM queue_ticket t
JOIN clinic c  ON c.clinic_id  = t.clinic_id
JOIN patient p ON p.patient_id = t.patient_id
LEFT JOIN vital_signs v ON v.vital_id =
  (SELECT MAX(v2.vital_id) FROM vital_signs v2 WHERE v2.ticket_id = t.ticket_id)
WHERE t.queue_date = CURDATE() AND t.status = 'WAITING';

-- ---------------------------------------------------------------------
-- hall_display: what the waiting-hall screen shows (ticket and room only,
-- no patient names)
-- ---------------------------------------------------------------------
CREATE VIEW hall_display AS
SELECT t.ticket_no, c.name AS clinic_name, c.location, t.called_at
FROM queue_ticket t
JOIN clinic c ON c.clinic_id = t.clinic_id
WHERE t.queue_date = CURDATE() AND t.status = 'CALLED';

-- ---------------------------------------------------------------------
-- pharmacy_queue: prescriptions waiting to be dispensed
-- ---------------------------------------------------------------------
CREATE VIEW pharmacy_queue AS
SELECT r.prescription_id, t.ticket_no, p.national_id, p.full_name AS patient_name,
       st.full_name AS doctor_name, r.medication, r.dosage, r.frequency,
       r.duration_days, co.created_at AS prescribed_at
FROM prescription r
JOIN consultation co ON co.consultation_id = r.consultation_id
JOIN queue_ticket t  ON t.ticket_id        = co.ticket_id
JOIN patient p       ON p.patient_id       = t.patient_id
JOIN staff st        ON st.staff_id        = co.doctor_id
WHERE r.status = 'PENDING';

-- ---------------------------------------------------------------------
-- Least-privilege account for the kiosk application (NFR-05, NFR-07):
-- it can read and create bookings and check in through check_in, but
-- never update or delete records, and never read staff or clinical data.
-- Change the password before the demo; keep it out of Git.
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'mq_kiosk'@'localhost';
CREATE USER 'mq_kiosk'@'localhost' IDENTIFIED BY 'change_me_kiosk';
GRANT SELECT ON mediqueue.patient              TO 'mq_kiosk'@'localhost';
GRANT SELECT ON mediqueue.clinic               TO 'mq_kiosk'@'localhost';
GRANT SELECT ON mediqueue.appointment_slot     TO 'mq_kiosk'@'localhost';
GRANT SELECT ON mediqueue.available_slot       TO 'mq_kiosk'@'localhost';
GRANT SELECT ON mediqueue.booking_confirmation TO 'mq_kiosk'@'localhost';
GRANT SELECT, INSERT ON mediqueue.appointment  TO 'mq_kiosk'@'localhost';
GRANT SELECT ON mediqueue.hall_display         TO 'mq_kiosk'@'localhost';
GRANT EXECUTE ON PROCEDURE mediqueue.check_in  TO 'mq_kiosk'@'localhost';

-- ---------------------------------------------------------------------
-- Account for the staff application (reception, nurse, doctor, pharmacy,
-- admin). The app checks staff.role before each action; the database
-- still blocks deleting records and editing finished clinical notes.
-- ---------------------------------------------------------------------
DROP USER IF EXISTS 'mq_staff'@'localhost';
CREATE USER 'mq_staff'@'localhost' IDENTIFIED BY 'change_me_staff';
GRANT SELECT ON mediqueue.*                    TO 'mq_staff'@'localhost';
GRANT INSERT, UPDATE ON mediqueue.staff        TO 'mq_staff'@'localhost';
GRANT INSERT, UPDATE ON mediqueue.doctor       TO 'mq_staff'@'localhost';
GRANT INSERT, UPDATE ON mediqueue.clinic       TO 'mq_staff'@'localhost';
GRANT INSERT, UPDATE ON mediqueue.appointment_slot TO 'mq_staff'@'localhost';
GRANT INSERT, UPDATE ON mediqueue.appointment  TO 'mq_staff'@'localhost';
GRANT UPDATE (status) ON mediqueue.queue_ticket TO 'mq_staff'@'localhost';
GRANT INSERT ON mediqueue.vital_signs          TO 'mq_staff'@'localhost';
GRANT INSERT ON mediqueue.consultation         TO 'mq_staff'@'localhost';
GRANT INSERT ON mediqueue.prescription         TO 'mq_staff'@'localhost';
GRANT UPDATE (status, dispensed_by, dispensed_at) ON mediqueue.prescription TO 'mq_staff'@'localhost';
GRANT EXECUTE ON PROCEDURE mediqueue.issue_ticket TO 'mq_staff'@'localhost';
GRANT EXECUTE ON PROCEDURE mediqueue.call_next    TO 'mq_staff'@'localhost';
