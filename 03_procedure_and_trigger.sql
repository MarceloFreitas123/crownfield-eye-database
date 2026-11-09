-- =====================================================================
-- 03_procedure_and_trigger.sql  |  Part C, Q5 and Q6
-- Author: Marcelo Freitas (G1431524)
-- =====================================================================
USE crownfield_eye;

DROP PROCEDURE IF EXISTS sp_patient_history;
DROP TRIGGER IF EXISTS trg_followup_date_check;
DROP TRIGGER IF EXISTS trg_followup_date_check_upd;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Q5  Stored procedure with an input parameter  (Figure 7)
-- Question: what is the full visit history of one patient?
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_patient_history (IN p_patient_number CHAR(5))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM patient WHERE patient_number = p_patient_number) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Unknown patient number';
    END IF;

    SELECT p.patient_number,
           CONCAT(p.first_name, ' ', p.last_name) AS patient,
           a.appointment_date,
           a.appointment_time,
           c.clinician_name,
           cl.clinic_name,
           d.diagnosis_description
    FROM patient p
    JOIN appointment a     ON a.patient_id     = p.patient_id
    JOIN clinician c       ON c.clinician_id   = a.clinician_id
    JOIN clinic cl         ON cl.clinic_id     = a.clinic_id
    LEFT JOIN diagnosis d  ON d.appointment_id = a.appointment_id
    WHERE p.patient_number = p_patient_number
    ORDER BY a.appointment_date, a.appointment_time;
END$$

-- ---------------------------------------------------------------------
-- Q6  Trigger enforcing a business rule  (Figure 8)
-- Rule: a follow-up cannot be due before the appointment that created it.
-- A CHECK constraint cannot compare columns in two tables, so a trigger is used.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_followup_date_check
BEFORE INSERT ON follow_up_plan
FOR EACH ROW
BEGIN
    DECLARE v_appt_date DATE;
    SELECT appointment_date INTO v_appt_date
    FROM appointment WHERE appointment_id = NEW.appointment_id;
    IF NEW.due_date < v_appt_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Follow-up due date cannot be earlier than the appointment date';
    END IF;
END$$

CREATE TRIGGER trg_followup_date_check_upd
BEFORE UPDATE ON follow_up_plan
FOR EACH ROW
BEGIN
    DECLARE v_appt_date DATE;
    SELECT appointment_date INTO v_appt_date
    FROM appointment WHERE appointment_id = NEW.appointment_id;
    IF NEW.due_date < v_appt_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Follow-up due date cannot be earlier than the appointment date';
    END IF;
END$$

DELIMITER ;

-- Demonstration of Q5 (Figure 7): expected 2 rows for OP001
CALL sp_patient_history('OP001');

-- The trigger is demonstrated by tests T6 (rejected) and T7 (accepted) in 06_tests.sql.
