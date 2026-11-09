-- =====================================================================
-- 02_individual_queries.sql  |  Part C, queries Q1 to Q4
-- Author: Marcelo Freitas (G1431524)
-- Q5 (stored procedure) and Q6 (trigger) are in 03_procedure_and_trigger.sql
-- =====================================================================
USE crownfield_eye;

-- ---------------------------------------------------------------------
-- Q1  Aggregate with GROUP BY and HAVING  (Figure 3)
-- Question: which clinicians carry two or more appointments?
-- Expected: Dr Maya Shah 4, Dr Omar Haddad 3, Dr Leo Grant 2
-- ---------------------------------------------------------------------
SELECT c.clinician_name,
       c.specialty,
       COUNT(*) AS appointments
FROM appointment a
JOIN clinician c ON c.clinician_id = a.clinician_id
GROUP BY c.clinician_id, c.clinician_name, c.specialty
HAVING COUNT(*) >= 2
ORDER BY appointments DESC;

-- ---------------------------------------------------------------------
-- Q2  INNER JOIN across four tables  (Figure 4)
-- Question: who is seen by whom at the City Road clinic, and when?
-- Expected: 6 rows, in date and time order
-- ---------------------------------------------------------------------
SELECT a.appointment_date,
       a.appointment_time,
       p.patient_number,
       CONCAT(p.first_name, ' ', p.last_name) AS patient,
       c.clinician_name,
       c.specialty,
       cl.clinic_name
FROM appointment a
INNER JOIN patient   p  ON p.patient_id    = a.patient_id
INNER JOIN clinician c  ON c.clinician_id  = a.clinician_id
INNER JOIN clinic    cl ON cl.clinic_id    = a.clinic_id
WHERE cl.clinic_name = 'City Road'
ORDER BY a.appointment_date, a.appointment_time;

-- ---------------------------------------------------------------------
-- Q3  LEFT JOIN revealing missing optional data  (Figure 5)
-- Question: which appointments have no follow-up plan?
-- Expected: 3 rows (appointments 8, 11 and 14) with NULL plan columns;
--           appointment 11 lost its plan in the Part B DELETE
-- ---------------------------------------------------------------------
SELECT a.appointment_id,
       p.patient_number,
       a.appointment_date,
       a.notes,
       f.follow_up_plan_id,
       f.due_date
FROM appointment a
JOIN patient p             ON p.patient_id     = a.patient_id
LEFT JOIN follow_up_plan f ON f.appointment_id = a.appointment_id
WHERE f.follow_up_plan_id IS NULL
ORDER BY a.appointment_id;

-- ---------------------------------------------------------------------
-- Q4  Common table expression  (Figure 6)
-- Question: which medicines are prescribed more often than average?
-- Expected: average 1.36 items per medicine; 5 medicines with 2 items
-- ---------------------------------------------------------------------
WITH medicine_use AS (
    SELECT m.medicine_name,
           COUNT(pi.prescription_item_id) AS times_prescribed
    FROM medicine m
    JOIN prescription_item pi ON pi.medicine_id = m.medicine_id
    GROUP BY m.medicine_id, m.medicine_name
)
SELECT medicine_name,
       times_prescribed,
       (SELECT ROUND(AVG(times_prescribed), 2) FROM medicine_use) AS average_use
FROM medicine_use
WHERE times_prescribed > (SELECT AVG(times_prescribed) FROM medicine_use)
ORDER BY times_prescribed DESC, medicine_name;
