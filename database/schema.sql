-- =====================================================================
-- MediQueue - Database Schema (MySQL 8.0+)
-- Scope: self-service kiosk appointment booking, per SRS (26 Oct 2026)
--   FR-01..FR-02  patient identification   -> patient
--   FR-03..FR-04  clinic selection         -> clinic
--   FR-05, FR-10  available times          -> appointment_slot + available_slot view
--   FR-06..FR-09, FR-11  booking           -> appointment
--   FR-08, NFR-03, NFR-08  no double booking -> uq_appointment_active_slot
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
-- appointment_slot: bookable times per clinic (glossary: "Appointment Slot")
-- ---------------------------------------------------------------------
CREATE TABLE appointment_slot (
  slot_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  clinic_id   SMALLINT UNSIGNED NOT NULL,
  start_time  DATETIME          NOT NULL,
  end_time    DATETIME          NOT NULL,
  PRIMARY KEY (slot_id),
  CONSTRAINT uq_slot_clinic_start UNIQUE (clinic_id, start_time),
  CONSTRAINT chk_slot_times CHECK (end_time > start_time),
  CONSTRAINT fk_slot_clinic FOREIGN KEY (clinic_id)
    REFERENCES clinic (clinic_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
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
-- Least-privilege account for the kiosk application (NFR-05, NFR-07):
-- it can read and create bookings but never update or delete records.
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
