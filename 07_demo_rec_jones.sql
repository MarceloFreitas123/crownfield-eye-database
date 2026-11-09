-- 07_demo_rec_jones.sql  |  Live demo, slide 11 (connection: rec_jones, password Jones#Demo2026)
-- Run one statement at a time with Ctrl+Enter.
SELECT CURRENT_USER();                                   -- rec_jones@localhost
SELECT * FROM crownfield_eye.prescription;               -- Error 1142: no clinical data
UPDATE crownfield_eye.follow_up_plan SET priority = 'Routine' WHERE appointment_id = 2;   -- Error 1143
