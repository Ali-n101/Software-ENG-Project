-- =====================================================================
-- MediQueue - Simulated data (NFR-06: no real patient records)
-- Run after schema.sql. Slots are generated relative to today, so the
-- kiosk always has upcoming times to show.
-- =====================================================================
USE mediqueue;

INSERT INTO patient (national_id, full_name, date_of_birth, gender, phone) VALUES
  ('1000000001', 'Test Patient One',   '1985-03-12', 'M', '0500000001'),
  ('1000000002', 'Test Patient Two',   '1992-07-24', 'F', '0500000002'),
  ('1000000003', 'Test Patient Three', '1948-11-02', 'M', '0500000003'),
  ('1000000004', 'Test Patient Four',  '2001-01-30', 'F', NULL),
  ('2000000005', 'Test Patient Five',  '1977-09-15', 'M', '0500000005');

INSERT INTO clinic (name, location, is_active) VALUES
  ('General Medicine', 'Building A, Floor 1, Room 101', TRUE),
  ('Pediatrics',       'Building A, Floor 2, Room 204', TRUE),
  ('Dermatology',      'Building B, Floor 1, Room 110', TRUE),
  ('Ophthalmology',    'Building B, Floor 2, Room 215', TRUE),
  ('Dentistry',        'Building C, Floor 1, Room 102', FALSE);  -- inactive: hidden from kiosk

-- 30-minute slots, 08:00-12:00, for the next 14 days, every clinic.
-- Dermatology gets none, to demonstrate the FR-10 "no times" message.
INSERT INTO appointment_slot (clinic_id, start_time, end_time)
WITH RECURSIVE
  days (d) AS (
    SELECT 1 UNION ALL SELECT d + 1 FROM days WHERE d < 14
  ),
  times (t) AS (
    SELECT TIME('08:00:00')
    UNION ALL
    SELECT ADDTIME(t, '00:30:00') FROM times WHERE t < TIME('11:30:00')
  )
SELECT c.clinic_id,
       TIMESTAMP(CURDATE() + INTERVAL days.d DAY, times.t),
       TIMESTAMP(CURDATE() + INTERVAL days.d DAY, times.t) + INTERVAL 30 MINUTE
FROM clinic c
CROSS JOIN days
CROSS JOIN times
WHERE c.name <> 'Dermatology';

-- A few existing bookings so some times already show as taken (FR-08).
INSERT INTO appointment (slot_id, patient_id)
SELECT s.slot_id, p.patient_id
FROM appointment_slot s
JOIN clinic c  ON c.clinic_id = s.clinic_id AND c.name = 'General Medicine'
JOIN patient p ON p.national_id = '1000000001'
WHERE s.start_time = TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '08:00:00');

INSERT INTO appointment (slot_id, patient_id)
SELECT s.slot_id, p.patient_id
FROM appointment_slot s
JOIN clinic c  ON c.clinic_id = s.clinic_id AND c.name = 'Pediatrics'
JOIN patient p ON p.national_id = '1000000002'
WHERE s.start_time = TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '09:00:00');
