-- =====================================================================
-- 04_security.sql  |  Part D: roles, data protection, secure coding,
--                     transactions.  Run as root (or an admin account).
-- Author: Marcelo Freitas (G1431524)
-- Demo passwords below are for this fictional prototype only.
-- =====================================================================
USE crownfield_eye;
SET SQL_SAFE_UPDATES = 0;   -- MySQL Workbench blocks key-less UPDATEs otherwise

-- =====================================================================
-- D1. Roles and least-privilege grants  (Table 2, Figure 9)
-- =====================================================================
DROP ROLE IF EXISTS role_admin, role_doctor, role_receptionist, role_patient;
CREATE ROLE role_admin, role_doctor, role_receptionist, role_patient;

-- Administrator: full control of this database only
GRANT ALL PRIVILEGES ON crownfield_eye.* TO role_admin;

-- Doctor: reads patients, updates visits, writes clinical records, never deletes
GRANT SELECT                 ON crownfield_eye.patient           TO role_doctor;
GRANT SELECT                 ON crownfield_eye.clinician         TO role_doctor;
GRANT SELECT                 ON crownfield_eye.clinic            TO role_doctor;
GRANT SELECT, UPDATE         ON crownfield_eye.appointment       TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.diagnosis         TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.prescription      TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.prescription_item TO role_doctor;
GRANT SELECT                 ON crownfield_eye.medicine          TO role_doctor;
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.follow_up_plan    TO role_doctor;

-- Receptionist: books visits and maintains patient details, no clinical data
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.patient           TO role_receptionist;
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.appointment       TO role_receptionist;
GRANT SELECT                 ON crownfield_eye.clinician         TO role_receptionist;
GRANT SELECT                 ON crownfield_eye.clinic            TO role_receptionist;
GRANT SELECT, UPDATE         ON crownfield_eye.follow_up_plan    TO role_receptionist;

-- Patient: own rows only, through views filtered by the login name
CREATE OR REPLACE VIEW v_my_details AS
    SELECT patient_number, first_name, last_name, postcode
    FROM patient
    WHERE patient_number = UPPER(SUBSTRING_INDEX(USER(), '@', 1));

CREATE OR REPLACE VIEW v_my_appointments AS
    SELECT p.patient_number, a.appointment_date, a.appointment_time,
           c.clinician_name, cl.clinic_name
    FROM appointment a
    JOIN patient p    ON p.patient_id    = a.patient_id
    JOIN clinician c  ON c.clinician_id  = a.clinician_id
    JOIN clinic cl    ON cl.clinic_id    = a.clinic_id
    WHERE p.patient_number = UPPER(SUBSTRING_INDEX(USER(), '@', 1));

CREATE OR REPLACE VIEW v_my_prescriptions AS
    SELECT p.patient_number, rx.prescribed_date, m.medicine_name,
           pi.dose, pi.route, pi.frequency, pi.duration
    FROM prescription rx
    JOIN appointment a        ON a.appointment_id   = rx.appointment_id
    JOIN patient p            ON p.patient_id       = a.patient_id
    JOIN prescription_item pi ON pi.prescription_id = rx.prescription_id
    JOIN medicine m           ON m.medicine_id      = pi.medicine_id
    WHERE p.patient_number = UPPER(SUBSTRING_INDEX(USER(), '@', 1));

GRANT SELECT ON crownfield_eye.v_my_details       TO role_patient;
GRANT SELECT ON crownfield_eye.v_my_appointments  TO role_patient;
GRANT SELECT ON crownfield_eye.v_my_prescriptions TO role_patient;

-- One demo account per role
DROP USER IF EXISTS 'admin_ops'@'localhost', 'dr_shah'@'localhost',
                    'rec_jones'@'localhost', 'op001'@'localhost';
CREATE USER 'admin_ops'@'localhost' IDENTIFIED BY 'Admin#Demo2026';
CREATE USER 'dr_shah'@'localhost'   IDENTIFIED BY 'Shah#Demo2026';
CREATE USER 'rec_jones'@'localhost' IDENTIFIED BY 'Jones#Demo2026';
CREATE USER 'op001'@'localhost'     IDENTIFIED BY 'Op001#Demo2026';

GRANT role_admin        TO 'admin_ops'@'localhost';
GRANT role_doctor       TO 'dr_shah'@'localhost';
GRANT role_receptionist TO 'rec_jones'@'localhost';
GRANT role_patient      TO 'op001'@'localhost';

SET DEFAULT ROLE ALL TO 'admin_ops'@'localhost', 'dr_shah'@'localhost',
                        'rec_jones'@'localhost', 'op001'@'localhost';

-- Access matrix as stored by the server
SHOW GRANTS FOR role_doctor;
SHOW GRANTS FOR role_receptionist;
SHOW GRANTS FOR role_patient;

-- =====================================================================
-- D2a. Salted password hashing  (Figure 10, top)
-- =====================================================================
DROP TABLE IF EXISTS app_user;
CREATE TABLE app_user (
    user_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(30) NOT NULL,
    role_name      VARCHAR(20) NOT NULL,
    salt           CHAR(32)    NOT NULL,
    password_hash  CHAR(64)    NOT NULL,
    CONSTRAINT uq_app_username UNIQUE (username),
    CONSTRAINT chk_app_role CHECK (role_name IN ('Administrator', 'Doctor', 'Receptionist', 'Patient'))
) ENGINE = InnoDB;

DROP PROCEDURE IF EXISTS sp_add_app_user;
DROP FUNCTION  IF EXISTS fn_login_ok;
DELIMITER $$
CREATE PROCEDURE sp_add_app_user (IN p_username VARCHAR(30), IN p_role VARCHAR(20), IN p_password VARCHAR(100))
BEGIN
    DECLARE v_salt CHAR(32) DEFAULT HEX(RANDOM_BYTES(16));     -- new random salt per user
    INSERT INTO app_user (username, role_name, salt, password_hash)
    VALUES (p_username, p_role, v_salt, SHA2(CONCAT(v_salt, p_password), 256));
END$$

CREATE FUNCTION fn_login_ok (p_username VARCHAR(30), p_password VARCHAR(100))
RETURNS TINYINT
READS SQL DATA
BEGIN
    RETURN EXISTS (SELECT 1 FROM app_user
                   WHERE username = p_username
                     AND password_hash = SHA2(CONCAT(salt, p_password), 256));
END$$
DELIMITER ;

CALL sp_add_app_user('admin_ops', 'Administrator', 'Admin#Demo2026');
CALL sp_add_app_user('dr_shah',   'Doctor',        'Shah#Demo2026');
CALL sp_add_app_user('rec_jones', 'Receptionist',  'Jones#Demo2026');
CALL sp_add_app_user('op001',     'Patient',       'Op001#Demo2026');

SELECT username, role_name, salt, password_hash FROM app_user;   -- no plain text stored
SELECT fn_login_ok('dr_shah', 'Shah#Demo2026') AS correct_password,  -- 1
       fn_login_ok('dr_shah', 'wrong-guess')   AS wrong_password;    -- 0

-- =====================================================================
-- D2b. AES encryption of clinical notes  (Figure 10, bottom)
-- In production the key would come from a key-management service, not a session variable.
-- =====================================================================
SET @aes_key = SHA2('crownfield-demo-key-2026', 256);

ALTER TABLE appointment ADD COLUMN notes_encrypted VARBINARY(512) NULL AFTER notes;
UPDATE appointment SET notes_encrypted = AES_ENCRYPT(notes, @aes_key);
UPDATE appointment SET notes = NULL;                               -- plain text cleared

SELECT appointment_id, notes, HEX(notes_encrypted) AS stored_ciphertext,
       CAST(AES_DECRYPT(notes_encrypted, @aes_key) AS CHAR(255)) AS decrypted_with_key
FROM appointment
WHERE appointment_id <= 5;

-- =====================================================================
-- D3. SQL injection: concatenated vs parameterised  (Figure 11)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_find_patient_unsafe;
DROP PROCEDURE IF EXISTS sp_find_patient_safe;
DELIMITER $$
-- UNSAFE on purpose: user input is pasted into the SQL text
CREATE PROCEDURE sp_find_patient_unsafe (IN p_surname VARCHAR(100))
BEGIN
    SET @sql_text = CONCAT('SELECT patient_number, first_name, last_name FROM patient WHERE last_name = ''', p_surname, '''');
    PREPARE stmt FROM @sql_text;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

-- SAFE: the input is bound to a placeholder and treated only as data
CREATE PROCEDURE sp_find_patient_safe (IN p_surname VARCHAR(100))
BEGIN
    SET @surname = p_surname;
    PREPARE stmt FROM 'SELECT patient_number, first_name, last_name FROM patient WHERE last_name = ?';
    EXECUTE stmt USING @surname;
    DEALLOCATE PREPARE stmt;
END$$
DELIMITER ;

CALL sp_find_patient_safe('Yusuf');                   -- normal use: 1 row
CALL sp_find_patient_unsafe('Yusuf'' OR ''1''=''1');  -- attack succeeds: all 14 patients
CALL sp_find_patient_safe('Yusuf'' OR ''1''=''1');    -- attack fails: 0 rows

-- =====================================================================
-- D4. Transaction: booking + prescription as one unit  (Figure 12)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_book_with_prescription;
DELIMITER $$
CREATE PROCEDURE sp_book_with_prescription (
    IN p_patient_number CHAR(5),   IN p_clinician_name VARCHAR(80), IN p_clinic_name VARCHAR(50),
    IN p_date DATE,                IN p_time TIME,                  IN p_medicine_name VARCHAR(80),
    IN p_dose VARCHAR(40),         IN p_route VARCHAR(30),          IN p_frequency VARCHAR(40),
    IN p_duration VARCHAR(30))
BEGIN
    DECLARE v_appt_id INT UNSIGNED;
    DECLARE v_rx_id INT UNSIGNED;
    DECLARE v_medicine_id INT UNSIGNED;
    DECLARE v_error TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        ROLLBACK;
        SELECT 'ROLLBACK' AS outcome, v_error AS reason;
    END;

    START TRANSACTION;

    INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
    SELECT p.patient_id, c.clinician_id, cl.clinic_id, p_date, p_time
    FROM patient p, clinician c, clinic cl
    WHERE p.patient_number = p_patient_number
      AND c.clinician_name = p_clinician_name
      AND cl.clinic_name   = p_clinic_name;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown patient, clinician or clinic';
    END IF;
    SET v_appt_id = LAST_INSERT_ID();

    INSERT INTO prescription (appointment_id, prescribed_date) VALUES (v_appt_id, p_date);
    SET v_rx_id = LAST_INSERT_ID();

    SELECT medicine_id INTO v_medicine_id FROM medicine WHERE medicine_name = p_medicine_name;
    IF v_medicine_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown medicine';
    END IF;

    INSERT INTO prescription_item (prescription_id, medicine_id, dose, route, frequency, duration)
    VALUES (v_rx_id, v_medicine_id, p_dose, p_route, p_frequency, p_duration);

    COMMIT;
    SELECT 'COMMIT' AS outcome, v_appt_id AS new_appointment_id;
END$$
DELIMITER ;

-- Counts before
SELECT (SELECT COUNT(*) FROM appointment) AS appointments,
       (SELECT COUNT(*) FROM prescription) AS prescriptions,
       (SELECT COUNT(*) FROM prescription_item) AS items;           -- 19, 14, 19

-- Valid booking: everything is saved
CALL sp_book_with_prescription('OP007', 'Dr Maya Shah', 'City Road', '2026-11-20', '10:00',
                               'Latanoprost', '1 drop', 'Topical (eye)', 'Once daily at night', '6 weeks');

-- Invalid booking: unknown medicine, so the appointment and prescription are rolled back
CALL sp_book_with_prescription('OP008', 'Dr Leo Grant', 'Ealing', '2026-11-21', '11:00',
                               'Notarealdrug', '1 drop', 'Topical (eye)', 'Twice daily', '2 weeks');

-- Counts after: only the valid booking was added
SELECT (SELECT COUNT(*) FROM appointment) AS appointments,
       (SELECT COUNT(*) FROM prescription) AS prescriptions,
       (SELECT COUNT(*) FROM prescription_item) AS items;           -- 20, 15, 20
