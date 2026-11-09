-- =====================================================================
-- 01_schema.sql  |  Crownfield Eye Hospital (fictional)  |  CPU4:103
-- Author: Marcelo Freitas (G1431524)
-- Creates the 3NF schema, loads Appendix 1 + synthetic data, and runs
-- the Part B controlled UPDATE and DELETE.  MySQL 8.0.16+ (CHECK enforced)
-- =====================================================================

DROP DATABASE IF EXISTS crownfield_eye;
CREATE DATABASE crownfield_eye CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE crownfield_eye;
SET SQL_SAFE_UPDATES = 0;   -- MySQL Workbench safe-update mode would block the Part B UPDATE

-- ---------------------------------------------------------------------
-- 1. Tables (parents first)
-- ---------------------------------------------------------------------
CREATE TABLE patient (
    patient_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_number  CHAR(5)      NOT NULL,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    postcode        VARCHAR(8)   NOT NULL,
    CONSTRAINT uq_patient_number UNIQUE (patient_number),
    CONSTRAINT chk_patient_number CHECK (patient_number LIKE 'OP___')
) ENGINE = InnoDB;

CREATE TABLE clinician (
    clinician_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clinician_name  VARCHAR(80)  NOT NULL,
    specialty       VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_clinician_name UNIQUE (clinician_name)
) ENGINE = InnoDB;

CREATE TABLE clinic (
    clinic_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clinic_name     VARCHAR(50)  NOT NULL,
    address         VARCHAR(120) NOT NULL,
    CONSTRAINT uq_clinic_name UNIQUE (clinic_name)
) ENGINE = InnoDB;

CREATE TABLE appointment (
    appointment_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT UNSIGNED NOT NULL,
    clinician_id     INT UNSIGNED NOT NULL,
    clinic_id        INT UNSIGNED NOT NULL,
    appointment_date DATE         NOT NULL,
    appointment_time TIME         NOT NULL,
    notes            VARCHAR(255) NULL,
    CONSTRAINT fk_appt_patient   FOREIGN KEY (patient_id)   REFERENCES patient (patient_id)     ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appt_clinician FOREIGN KEY (clinician_id) REFERENCES clinician (clinician_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appt_clinic    FOREIGN KEY (clinic_id)    REFERENCES clinic (clinic_id)       ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_patient_slot   UNIQUE (patient_id, appointment_date, appointment_time),
    CONSTRAINT chk_clinic_hours  CHECK (appointment_time BETWEEN '08:00:00' AND '18:00:00')
) ENGINE = InnoDB;

CREATE TABLE diagnosis (
    diagnosis_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id        INT UNSIGNED NOT NULL,
    diagnosis_description VARCHAR(120) NOT NULL,
    CONSTRAINT fk_diag_appt FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id) ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE prescription (
    prescription_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id   INT UNSIGNED NOT NULL,
    prescribed_date  DATE         NOT NULL,
    CONSTRAINT fk_rx_appt FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id) ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE medicine (
    medicine_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicine_name  VARCHAR(80) NOT NULL,
    CONSTRAINT uq_medicine_name UNIQUE (medicine_name)
) ENGINE = InnoDB;

CREATE TABLE prescription_item (
    prescription_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    prescription_id      INT UNSIGNED NOT NULL,
    medicine_id          INT UNSIGNED NOT NULL,
    dose                 VARCHAR(40)  NOT NULL,
    route                VARCHAR(30)  NOT NULL,
    frequency            VARCHAR(40)  NOT NULL,
    duration             VARCHAR(30)  NOT NULL,
    CONSTRAINT fk_item_rx       FOREIGN KEY (prescription_id) REFERENCES prescription (prescription_id) ON DELETE CASCADE,
    CONSTRAINT fk_item_medicine FOREIGN KEY (medicine_id)     REFERENCES medicine (medicine_id)         ON DELETE RESTRICT,
    CONSTRAINT uq_rx_medicine   UNIQUE (prescription_id, medicine_id)
) ENGINE = InnoDB;

CREATE TABLE follow_up_plan (
    follow_up_plan_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id    INT UNSIGNED NOT NULL,
    interval_weeks    TINYINT UNSIGNED NOT NULL,
    due_date          DATE         NOT NULL,
    priority          VARCHAR(10)  NOT NULL,
    status            VARCHAR(10)  NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_fup_appt      FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id) ON DELETE RESTRICT,
    CONSTRAINT uq_fup_appt      UNIQUE (appointment_id),
    CONSTRAINT chk_fup_interval CHECK (interval_weeks BETWEEN 1 AND 104),
    CONSTRAINT chk_fup_priority CHECK (priority IN ('Routine', 'High', 'Urgent')),
    CONSTRAINT chk_fup_status   CHECK (status IN ('Pending', 'Booked', 'Completed', 'Cancelled'))
) ENGINE = InnoDB;

-- ALTER TABLE: a clinician cannot be double-booked
ALTER TABLE appointment
    ADD CONSTRAINT uq_clinician_slot UNIQUE (clinician_id, appointment_date, appointment_time);

-- ---------------------------------------------------------------------
-- 2. Data: rows marked (A1) come from Appendix 1, the rest are synthetic
-- ---------------------------------------------------------------------
INSERT INTO patient (patient_number, first_name, last_name, postcode) VALUES
('OP001', 'Amina',   'Yusuf',    'NE1 4AB'),   -- A1
('OP002', 'Daniel',  'Reed',     'N16 7QP'),   -- A1
('OP003', 'Sofia',   'Bennett',  'E8 2LD'),    -- A1
('OP004', 'Michael', 'Okoro',    'SE6 3RT'),   -- A1
('OP005', 'Grace',   'Turner',   'N1 2XY'),
('OP006', 'Liam',    'Patel',    'E14 5RT'),
('OP007', 'Chloe',   'Martin',   'SW9 8LP'),
('OP008', 'Ethan',   'Brooks',   'W3 6QD'),
('OP009', 'Fatima',  'Khan',     'E7 9HB'),
('OP010', 'Noah',    'Williams', 'WD17 1AA'),
('OP011', 'Isla',    'Murphy',   'LU1 3TT'),
('OP012', 'Ravi',    'Sharma',   'RG1 4PL'),
('OP013', 'Emma',    'Clarke',   'KT1 2EE'),
('OP014', 'Jacob',   'Hughes',   'EN5 1DJ');

INSERT INTO clinician (clinician_name, specialty) VALUES
('Dr Maya Shah',      'Glaucoma'),                    -- A1
('Dr Leo Grant',      'Retina'),                      -- A1
('Dr Priya Nair',     'Cornea'),                      -- A1
('Dr Omar Haddad',    'Medical retina'),              -- corrected in Part B
('Dr Hannah Cole',    'Paediatric ophthalmology'),
('Dr Samuel Adeyemi', 'Oculoplastics'),
('Dr Laura Kim',      'Neuro-ophthalmology'),
('Dr Tom Fischer',    'Cataract'),
('Dr Aisha Rahman',   'Uveitis'),
('Dr Ben Walsh',      'Strabismus'),
('Dr Grace Osei',     'Cornea'),
('Dr Daniel Moreau',  'Glaucoma'),
('Dr Ruth Evans',     'Retina');

INSERT INTO clinic (clinic_name, address) VALUES
('City Road',  '10 City Road, London'),   -- A1
('Bedford',    '2 Kempston Road, Bedford'),     -- A1
('Croydon',    '5 Park Lane, Croydon'),   -- A1
('Ealing',     '14 Uxbridge Road, Ealing'),
('Stratford',  '8 Broadway, Stratford'),
('Watford',    '21 Vicarage Road, Watford'),
('Luton',      '3 Dunstable Road, Luton'),
('Reading',    '40 London Road, Reading'),
('Kingston',   '9 Wood Street, Kingston'),
('Barnet',     '17 Wellhouse Lane, Barnet'),
('Harrow',     '6 Station Road, Harrow'),
('Romford',    '12 South Street, Romford'),
('Guildford',  '4 Epsom Road, Guildford');

INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time, notes) VALUES
( 1,  1,  1, '2026-10-05', '09:00', 'Review IOP'),                    -- 1  A1
( 2,  2,  1, '2026-10-05', '09:30', 'OCT before review'),             -- 2  A1
( 1,  1,  2, '2026-11-16', '10:15', 'Visual field test'),             -- 3  A1
( 3,  1,  1, '2026-10-06', '11:00', 'Monitor'),                       -- 4  A1
( 4,  3,  3, '2026-10-07', '14:00', 'Corneal topography'),            -- 5  A1
( 5,  1,  1, '2026-10-12', '09:00', 'New referral, raised IOP'),      -- 6
( 6,  2,  4, '2026-10-13', '10:00', 'Anti-VEGF injection'),           -- 7
( 7,  4,  1, '2026-10-14', '13:30', 'Retinal photography'),           -- 8
( 8,  4,  5, '2026-10-15', '15:00', 'Diabetic eye screening'),        -- 9
( 9,  4,  1, '2026-10-20', '11:30', 'Macular review'),                -- 10
(10,  5,  6, '2026-10-21', '09:45', 'Paediatric squint check'),       -- 11
(11,  6,  7, '2026-10-22', '10:30', 'Eyelid lesion review'),          -- 12
(12,  7,  8, '2026-10-23', '14:15', 'Optic disc swelling'),           -- 13
(13,  8,  9, '2026-10-26', '08:30', 'Cataract pre-assessment'),       -- 14
(14,  9, 10, '2026-10-27', '16:00', 'Uveitis flare'),                 -- 15
( 2, 10,  4, '2026-10-28', '12:00', 'Double vision assessment'),      -- 16
( 3, 11,  3, '2026-10-29', '10:00', 'Dry eye review'),                -- 17
( 5, 12,  2, '2026-11-02', '11:15', 'Second opinion glaucoma'),       -- 18
( 6, 13,  5, '2026-11-03', '09:15', 'Post-op retinal detachment');    -- 19

INSERT INTO diagnosis (appointment_id, diagnosis_description) VALUES
( 1, 'Ocular hypertension'),            -- A1
( 2, 'Diabetic macular oedema'),        -- A1
( 3, 'Ocular hypertension'),            -- A1
( 4, 'Glaucoma suspect'),               -- A1
( 5, 'Keratoconus'),                    -- A1
( 6, 'Primary open-angle glaucoma'),
( 7, 'Wet age-related macular degeneration'),
( 8, 'Background diabetic retinopathy'),
( 9, 'No diabetic retinopathy'),
(10, 'Central serous chorioretinopathy'),
(11, 'Intermittent exotropia'),
(12, 'Chalazion'),
(13, 'Papilloedema'),
(14, 'Age-related cataract'),
(15, 'Anterior uveitis'),
(16, 'Sixth nerve palsy'),
(17, 'Dry eye disease'),
(18, 'Normal-tension glaucoma'),
(19, 'Retinal detachment, repaired');

INSERT INTO medicine (medicine_name) VALUES
('Latanoprost'), ('Timolol'), ('Aflibercept'), ('Sodium chloride 5% drops'),
('Ranibizumab'), ('Prednisolone acetate 1%'), ('Atropine 1%'), ('Chloramphenicol 0.5%'),
('Brimonidine'), ('Dorzolamide'), ('Carbomer gel'), ('Cyclopentolate 1%'),
('Bimatoprost'), ('Acetazolamide'), ('Hypromellose 0.3%');

INSERT INTO prescription (appointment_id, prescribed_date) VALUES
( 1, '2026-10-05'),  -- 1  A1
( 2, '2026-10-05'),  -- 2  A1
( 3, '2026-11-16'),  -- 3  A1
( 5, '2026-10-07'),  -- 4  A1 (appointment 4 = "None": no prescription)
( 6, '2026-10-12'),  -- 5
( 7, '2026-10-13'),  -- 6
(10, '2026-10-20'),  -- 7
(12, '2026-10-22'),  -- 8
(13, '2026-10-23'),  -- 9
(14, '2026-10-26'),  -- 10
(15, '2026-10-27'),  -- 11
(17, '2026-10-29'),  -- 12
(18, '2026-11-02'),  -- 13
(19, '2026-11-03');  -- 14

INSERT INTO prescription_item (prescription_id, medicine_id, dose, route, frequency, duration) VALUES
( 1,  1, '1 drop',      'Topical (eye)',   'Once daily at night', '6 weeks'),   -- A1
( 1,  2, '1 drop',      'Topical (eye)',   'Twice daily',         '6 weeks'),   -- A1
( 2,  3, '2 mg',        'Intravitreal',    'Once',                'Single dose'),-- A1
( 3,  1, '1 drop',      'Topical (eye)',   'Once daily at night', '12 weeks'),  -- A1
( 4,  4, '1 drop',      'Topical (eye)',   'Four times daily',    '8 weeks'),   -- A1
( 5,  2, '1 drop',      'Topical (eye)',   'Twice daily',         '12 weeks'),
( 5,  9, '1 drop',      'Topical (eye)',   'Twice daily',         '12 weeks'),
( 6,  3, '2 mg',        'Intravitreal',    'Once',                'Single dose'),
( 7,  5, '0.5 mg',      'Intravitreal',    'Once',                'Single dose'),
( 8,  8, '1 drop',      'Topical (eye)',   'Four times daily',    '7 days'),
( 9, 14, '250 mg',      'Oral',            'Twice daily',         '14 days'),
(10, 12, '1 drop',      'Topical (eye)',   'Once before exam',    'Single dose'),
(11,  6, '1 drop',      'Topical (eye)',   'Hourly, then taper',  '4 weeks'),
(11,  7, '1 drop',      'Topical (eye)',   'Twice daily',         '2 weeks'),
(12, 11, '1 drop',      'Topical (eye)',   'Three times daily',   '8 weeks'),
(13, 13, '1 drop',      'Topical (eye)',   'Once daily at night', '12 weeks'),
(13, 10, '1 drop',      'Topical (eye)',   'Three times daily',   '12 weeks'),
(13,  9, '1 drop',      'Topical (eye)',   'Twice daily',         '12 weeks'),
(14,  6, '1 drop',      'Topical (eye)',   'Four times daily',    '4 weeks');

INSERT INTO follow_up_plan (appointment_id, interval_weeks, due_date, priority, status) VALUES
( 1,  6, '2026-11-16', 'High',    'Booked'),     -- A1
( 2,  4, '2026-11-02', 'Urgent',  'Booked'),     -- A1
( 3, 12, '2027-02-08', 'Routine', 'Pending'),    -- A1
( 4, 26, '2027-04-06', 'Routine', 'Pending'),    -- A1
( 5,  8, '2026-12-02', 'Routine', 'Pending'),    -- A1
( 6,  4, '2026-11-09', 'High',    'Booked'),
( 7,  4, '2026-11-10', 'Urgent',  'Booked'),
( 9, 52, '2027-10-14', 'Routine', 'Pending'),
(10,  6, '2026-12-01', 'Routine', 'Pending'),
(11, 12, '2027-01-13', 'Routine', 'Cancelled'),  -- deleted in Part B
(12,  3, '2026-11-12', 'Routine', 'Completed'),
(13,  1, '2026-10-30', 'Urgent',  'Completed'),
(15,  2, '2026-11-10', 'High',    'Booked'),
(16,  6, '2026-12-09', 'Routine', 'Pending'),
(17, 10, '2027-01-07', 'Routine', 'Pending'),
(18,  8, '2026-12-28', 'High',    'Pending'),
(19,  2, '2026-11-17', 'Urgent',  'Pending');
-- appointments 8 and 14 have no follow-up plan

-- ---------------------------------------------------------------------
-- 3. Row counts after loading
-- ---------------------------------------------------------------------
SELECT 'patient' AS table_name, COUNT(*) AS row_count FROM patient
UNION ALL SELECT 'clinician', COUNT(*) FROM clinician
UNION ALL SELECT 'clinic', COUNT(*) FROM clinic
UNION ALL SELECT 'appointment', COUNT(*) FROM appointment
UNION ALL SELECT 'diagnosis', COUNT(*) FROM diagnosis
UNION ALL SELECT 'prescription', COUNT(*) FROM prescription
UNION ALL SELECT 'prescription_item', COUNT(*) FROM prescription_item
UNION ALL SELECT 'medicine', COUNT(*) FROM medicine
UNION ALL SELECT 'follow_up_plan', COUNT(*) FROM follow_up_plan;

-- ---------------------------------------------------------------------
-- 4. Part B controlled UPDATE and DELETE (Figure 2)
-- ---------------------------------------------------------------------
-- 4a. UPDATE: standardise Dr Haddad's specialty (one row, three appointments follow)
SELECT c.clinician_name, c.specialty, a.appointment_id
FROM clinician c JOIN appointment a ON a.clinician_id = c.clinician_id
WHERE c.clinician_name = 'Dr Omar Haddad';                    -- before

UPDATE clinician SET specialty = 'Retina'
WHERE clinician_name = 'Dr Omar Haddad';                      -- 1 row affected

SELECT c.clinician_name, c.specialty, a.appointment_id
FROM clinician c JOIN appointment a ON a.clinician_id = c.clinician_id
WHERE c.clinician_name = 'Dr Omar Haddad';                    -- after

-- 4b. DELETE: remove the cancelled follow-up plan; its appointment remains
DELETE FROM follow_up_plan
WHERE appointment_id = 11 AND status = 'Cancelled';           -- 1 row affected

SELECT a.appointment_id, a.notes, f.follow_up_plan_id
FROM appointment a LEFT JOIN follow_up_plan f ON f.appointment_id = a.appointment_id
WHERE a.appointment_id = 11;                                  -- appointment kept, plan NULL

-- The rejected DELETE of patient OP001 (error 1451) is test T3 in 06_tests.sql.
