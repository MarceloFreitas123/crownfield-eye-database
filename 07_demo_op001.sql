-- 07_demo_op001.sql  |  Live demo, slide 11 (connection: op001, password Op001#Demo2026)
-- Run one statement at a time with Ctrl+Enter.
SELECT CURRENT_USER();                                   -- op001@localhost
SELECT * FROM crownfield_eye.v_my_appointments;          -- only OP001: 2 rows
SELECT * FROM crownfield_eye.patient;                    -- Error 1142: no base tables
