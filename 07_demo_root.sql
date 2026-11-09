-- =====================================================================
-- 07_demo_root.sql  |  Live demo for the recording (connection: root)
-- Author: Marcelo Freitas (G1431524)
-- Run ONE statement at a time with Ctrl+Enter (cursor on the statement).
-- Safe to repeat: nothing here changes the data permanently.
-- =====================================================================
USE crownfield_eye;
SET SQL_SAFE_UPDATES = 0;

-- ---------- DEMO 1 (slide 9): implemented database and integrity ----------
SELECT 'patient' AS table_name, COUNT(*) AS row_count FROM patient
UNION ALL SELECT 'clinician', COUNT(*) FROM clinician
UNION ALL SELECT 'clinic', COUNT(*) FROM clinic
UNION ALL SELECT 'appointment', COUNT(*) FROM appointment
UNION ALL SELECT 'prescription', COUNT(*) FROM prescription
UNION ALL SELECT 'medicine', COUNT(*) FROM medicine
UNION ALL SELECT 'follow_up_plan', COUNT(*) FROM follow_up_plan;

-- FOREIGN KEY: a patient with visits cannot be deleted      -> Error 1451
DELETE FROM patient WHERE patient_number = 'OP001';

-- CHECK: appointment outside clinic hours                    -> Error 3819
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
VALUES (2, 3, 3, '2026-11-25', '20:00');

-- ---------- DEMO 2 (slide 10): stored procedure and trigger ----------
CALL sp_patient_history('OP001');          -- 2 visits for Amina Yusuf
CALL sp_patient_history('OP999');          -- Error 1644 'Unknown patient number'

-- Trigger: follow-up due before its appointment (2026-10-26) -> Error 1644
INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority)
VALUES (14, 4, '2026-10-01', 'Routine');

-- Trigger: a valid due date is accepted (inside a transaction, then undone)
START TRANSACTION;
INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority)
VALUES (14, 4, '2026-11-23', 'Routine');
SELECT appointment_id, due_date, priority, status FROM follow_up_plan WHERE appointment_id = 14;
ROLLBACK;

-- ---------- DEMO 3 (slide 11): data protection and secure coding ----------
SELECT username, role_name, salt, password_hash FROM app_user;           -- no plain text
SELECT appointment_id, notes, HEX(notes_encrypted) AS stored_ciphertext
FROM appointment WHERE appointment_id <= 3;                                -- notes are ciphertext

CALL sp_find_patient_unsafe('Yusuf'' OR ''1''=''1');   -- injection works: 14 patients
CALL sp_find_patient_safe('Yusuf'' OR ''1''=''1');     -- parameterised: 0 rows

-- ---------- DEMO 4 (slide 11): transaction COMMIT and ROLLBACK ----------
-- Reset: remove the demo booking left by an earlier run, so the counts start at 19, 14, 19
DELETE pi FROM prescription_item pi
JOIN prescription rx ON rx.prescription_id = pi.prescription_id
JOIN appointment a   ON a.appointment_id   = rx.appointment_id
JOIN patient p       ON p.patient_id       = a.patient_id
WHERE p.patient_number = 'OP007' AND a.appointment_date = '2026-11-20' AND a.appointment_time = '10:00';
DELETE rx FROM prescription rx
JOIN appointment a ON a.appointment_id = rx.appointment_id
JOIN patient p     ON p.patient_id     = a.patient_id
WHERE p.patient_number = 'OP007' AND a.appointment_date = '2026-11-20' AND a.appointment_time = '10:00';
DELETE a FROM appointment a
JOIN patient p ON p.patient_id = a.patient_id
WHERE p.patient_number = 'OP007' AND a.appointment_date = '2026-11-20' AND a.appointment_time = '10:00';

SELECT (SELECT COUNT(*) FROM appointment) AS appointments,
       (SELECT COUNT(*) FROM prescription) AS prescriptions,
       (SELECT COUNT(*) FROM prescription_item) AS items;                 -- 19, 14, 19

CALL sp_book_with_prescription('OP007', 'Dr Maya Shah', 'City Road', '2026-11-20', '10:00',
                               'Latanoprost', '1 drop', 'Topical (eye)', 'Once daily at night', '6 weeks');   -- COMMIT

CALL sp_book_with_prescription('OP008', 'Dr Leo Grant', 'Ealing', '2026-11-21', '11:00',
                               'Notarealdrug', '1 drop', 'Topical (eye)', 'Twice daily', '2 weeks');           -- ROLLBACK

SELECT (SELECT COUNT(*) FROM appointment) AS appointments,
       (SELECT COUNT(*) FROM prescription) AS prescriptions,
       (SELECT COUNT(*) FROM prescription_item) AS items;                 -- 20, 15, 20
