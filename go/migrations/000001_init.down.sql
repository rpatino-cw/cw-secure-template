-- 000001_init.down.sql — Drops the users table.

DROP INDEX IF EXISTS idx_users_okta_sub;
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
