-- =====================================================================
-- MediQueue - Simulated data (NFR-06: no real patient records)
-- Run after schema.sql. Slots and today's queue are generated relative to
-- the day you load it, so the demo always has current data.
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

-- Demo staff accounts. DEMO ONLY: every account's password is
-- MediQueue-Demo-2026 and this file is on GitHub, so never reuse it.
-- Hashes are PBKDF2-HMAC-SHA256, 600000 iterations (see README).
INSERT INTO staff (username, full_name, role, password_hash, password_salt, password_iter) VALUES
  ('admin', 'Test Admin', 'ADMIN', '3379e53816712542f7f4bce6c3964e2a71a048366a23847020adcfc8c2d26f89', '08352470d4fab7f151648946b2564c0f', 600000),
  ('reception1', 'Test Receptionist', 'RECEPTIONIST', 'be02925187c8c499453036564053190c1795d9e0ec4693847954ad0d787638b3', '17b90f1ef72ac4533aca1194cf0c87ad', 600000),
  ('nurse1', 'Test Nurse One', 'NURSE', 'f012358d3f3bff78bc541508060041504efbe4e2a6ec650383b2b27efbe6ddc6', '060e16c0c91c614e221e4f96738b6bc7', 600000),
  ('nurse2', 'Test Nurse Two', 'NURSE', 'eee9a808c8acb07a140deca0080f2de71f7a1041e304445b320d999d4d49b7eb', '22cb7adc7e39b7c35da085d86d73b9e2', 600000),
  ('dr.general', 'Dr. Test General', 'DOCTOR', 'cf2d40806a1ba6d5ac2504de093658269edd1fd8f0f16a62c45e43ee8ca480b3', '69d379a420365205fd211b108d4dab6d', 600000),
  ('dr.peds', 'Dr. Test Pediatrics', 'DOCTOR', 'aba597d11f22339b6a78786d07f550f1d965b5894b1f27a5124de23381e449de', '7656a6e5f7af578320461c785823321a', 600000),
  ('dr.eye', 'Dr. Test Ophthalmology', 'DOCTOR', '660e8a85c29a66606c270f9b50901ca3b74aa37205fdbee32e6ae1c63722a6fc', '433114ad3d1bcbab4cd0899d788eb115', 600000),
  ('dr.derm', 'Dr. Test Dermatology', 'DOCTOR', 'd8d0a0e4551bd53cb26297a962fa11fb7bbfbce3ca3e5c380afffbb89f5432b7', 'fa40b2b12ca6e50ff57c49b8dfb4986e', 600000),
  ('pharma1', 'Test Pharmacist', 'PHARMACIST', 'd32888bc7039c0d211fa0488dc4263e27f582e45522d96a495117751c8c4d5b2', '52154824e3b184e97aa3f2bf5a5f70f9', 600000);

INSERT INTO doctor (staff_id, clinic_id, specialty)
SELECT s.staff_id, c.clinic_id, x.specialty
FROM (SELECT 'dr.general' AS username, 'General Medicine' AS clinic, 'Family Medicine' AS specialty
      UNION ALL SELECT 'dr.peds',    'Pediatrics',    'Pediatrics'
      UNION ALL SELECT 'dr.eye',     'Ophthalmology', 'Ophthalmology'
      UNION ALL SELECT 'dr.derm',    'Dermatology',   'Dermatology') x
JOIN staff s  ON s.username = x.username
JOIN clinic c ON c.name     = x.clinic;

-- 30-minute slots, 08:00-12:00, today and the next 14 days, every clinic,
-- each assigned to the clinic's doctor (Dentistry has none, so NULL).
-- Dermatology gets none, to demonstrate the FR-10 "no times" message.
INSERT INTO appointment_slot (clinic_id, doctor_id, start_time, end_time)
WITH RECURSIVE
  days (d) AS (
    SELECT 0 UNION ALL SELECT d + 1 FROM days WHERE d < 14
  ),
  times (t) AS (
    SELECT TIME('08:00:00')
    UNION ALL
    SELECT ADDTIME(t, '00:30:00') FROM times WHERE t < TIME('11:30:00')
  )
SELECT c.clinic_id, d.staff_id,
       TIMESTAMP(CURDATE() + INTERVAL days.d DAY, times.t),
       TIMESTAMP(CURDATE() + INTERVAL days.d DAY, times.t) + INTERVAL 30 MINUTE
FROM clinic c
LEFT JOIN doctor d ON d.clinic_id = c.clinic_id
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

-- ---------------------------------------------------------------------
-- Today's queue, so the staff screens have something to show
-- ---------------------------------------------------------------------
SELECT staff_id INTO @reception FROM staff WHERE username = 'reception1';
SELECT staff_id INTO @nurse     FROM staff WHERE username = 'nurse1';
SELECT staff_id INTO @dr_gen    FROM staff WHERE username = 'dr.general';
SELECT staff_id INTO @pharma    FROM staff WHERE username = 'pharma1';
SELECT clinic_id INTO @general  FROM clinic WHERE name = 'General Medicine';

-- Two bookings for today, then both patients check in at the kiosk
INSERT INTO appointment (slot_id, patient_id)
SELECT s.slot_id, p.patient_id
FROM appointment_slot s
JOIN clinic c  ON c.clinic_id = s.clinic_id AND c.name = 'General Medicine'
JOIN patient p ON p.national_id = '1000000002'
WHERE s.start_time = TIMESTAMP(CURDATE(), '10:00:00');
CALL issue_ticket('APPOINTMENT', NULL, NULL, LAST_INSERT_ID(), NULL, @t);

INSERT INTO appointment (slot_id, patient_id)
SELECT s.slot_id, p.patient_id
FROM appointment_slot s
JOIN clinic c  ON c.clinic_id = s.clinic_id AND c.name = 'Pediatrics'
JOIN patient p ON p.national_id = '1000000004'
WHERE s.start_time = TIMESTAMP(CURDATE(), '10:30:00');
CALL issue_ticket('APPOINTMENT', NULL, NULL, LAST_INSERT_ID(), NULL, @t);

-- An elderly walk-in at the assisted desk, and an emergency
SELECT patient_id INTO @p3 FROM patient WHERE national_id = '1000000003';
SELECT patient_id INTO @p5 FROM patient WHERE national_id = '2000000005';
CALL issue_ticket('SENIOR',    @p3, @general, NULL, @reception, @t);
CALL issue_ticket('EMERGENCY', @p5, @general, NULL, @reception, @t);

-- The nurse records vitals for both walk-ins
INSERT INTO vital_signs (ticket_id, nurse_id, systolic, diastolic, pulse, temperature)
SELECT ticket_id, @nurse, 150, 95, 112, 38.6 FROM queue_ticket
WHERE queue_date = CURDATE() AND ticket_type = 'EMERGENCY';
INSERT INTO vital_signs (ticket_id, nurse_id, systolic, diastolic, pulse, temperature)
SELECT ticket_id, @nurse, 135, 85, 76, 36.9 FROM queue_ticket
WHERE queue_date = CURDATE() AND ticket_type = 'SENIOR';

-- The doctor calls the next patient (the emergency goes first), sees
-- them, and prescribes two medicines; the pharmacy dispenses one.
CALL call_next(@general, @dr_gen, @called);
INSERT INTO consultation (ticket_id, doctor_id, diagnosis, notes)
SELECT ticket_id, @dr_gen, 'Acute febrile illness', 'Fever for 2 days. Review in 3 days if no better.'
FROM queue_ticket WHERE queue_date = CURDATE() AND ticket_no = @called;
SET @consult = LAST_INSERT_ID();
INSERT INTO prescription (consultation_id, medication, dosage, frequency, duration_days) VALUES
  (@consult, 'Paracetamol', '500 mg', 'every 6 hours as needed', 3),
  (@consult, 'Oral rehydration salts', '1 sachet', 'after each loose stool', 2);
UPDATE prescription
SET status = 'DISPENSED', dispensed_by = @pharma, dispensed_at = NOW()
WHERE consultation_id = @consult AND medication = 'Paracetamol';
