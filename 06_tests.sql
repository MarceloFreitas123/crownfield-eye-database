-- =====================================================================
-- 06_tests.sql  |  Test log: constraint, trigger and role tests
-- Author: Marcelo Freitas (G1431524)
-- Run ONE statement at a time (Ctrl+Enter in MySQL Workbench): the
-- "expected error" tests are meant to fail, and a failing statement
-- stops a full-script run.
-- =====================================================================
USE crownfield_eye;

-- T1  CHECK: invalid priority                       Expected: Error 3819 (chk_fup_priority)
INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority)
VALUES (14, 4, '2026-11-23', 'Soon');

-- T2  UNIQUE: duplicate patient number               Expected: Error 1062 (uq_patient_number)
INSERT INTO patient (patient_number, first_name, last_name, postcode)
VALUES ('OP001', 'Test', 'Duplicate', 'N1 1AA');

-- T3  FOREIGN KEY: delete a patient who has visits   Expected: Error 1451 (fk_appt_patient)
DELETE FROM patient WHERE patient_number = 'OP001';

-- T4  CHECK: appointment outside clinic hours        Expected: Error 3819 (chk_clinic_hours)
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
VALUES (2, 3, 3, '2026-11-25', '20:00');

-- T5  UNIQUE (ALTER TABLE): double-booked clinician  Expected: Error 1062 (uq_clinician_slot)
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
VALUES (3, 1, 1, '2026-10-05', '09:00');

-- T6  TRIGGER: due date before the appointment       Expected: Error 1644 (trg_followup_date_check)
INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority)
VALUES (14, 4, '2026-10-01', 'Routine');

-- T7  TRIGGER: valid due date is accepted            Expected: 1 row affected, status defaults to 'Pending'
INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority)
VALUES (8, 4, '2026-11-11', 'Routine');
SELECT * FROM follow_up_plan WHERE appointment_id = 8;

-- T8  PROCEDURE: unknown patient number              Expected: Error 1644 'Unknown patient number'
CALL sp_patient_history('OP999');

-- =====================================================================
-- Role tests (Figure 9). Open a NEW connection in Workbench for each
-- user (Database > Connect to Database, username + password from
-- 04_security.sql), then run the lines below in that connection.
-- =====================================================================

-- R1  as dr_shah     Expected: Error 1142 DELETE command denied
-- DELETE FROM crownfield_eye.prescription WHERE prescription_id = 1;

-- R2  as rec_jones   Expected: Error 1142 SELECT command denied
-- SELECT * FROM crownfield_eye.prescription;

-- R3  as op001       Expected: only OP001 rows (2 appointments, 3 prescription lines)
-- SELECT * FROM crownfield_eye.v_my_appointments;
-- SELECT * FROM crownfield_eye.v_my_prescriptions;

-- R4  as op001       Expected: Error 1142 SELECT command denied (no access to base tables)
-- SELECT * FROM crownfield_eye.patient;
