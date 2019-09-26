-- postgres-migrations
--
-- A simple SQL-based migration system.
-- Stores the information of which migrations were already run in a table.
--
-- This file provides a function
--
--     perform_migration(migration_number, 'Description text')
--
-- to be used like this:
--
--     migration := 42;
--     IF (SELECT perform_migration(migration, 'Add address to users table')) THEN
--       RAISE NOTICE 'Performing migration %', migration;
--
--       -- Migration commands here
--       ALTER TABLE users ADD COLUMN address TEXT; -- nullable
--
--     ELSE
--       RAISE NOTICE 'Not performing migration %', migration;
--     END IF;
--
-- A common usage pattern is that at the startup of your application
-- (e.g. its web-server), all migrations are run in order.
-- As shown above, migrations that were already run are automatically skipped.
--
-- All migrations are wrapped in transactions with SERIALIZABLE transaction
-- level, ensuring that any DDL or data changes done by the migrations
-- are fully rolled back if the migration fails.

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Note: `create or replace function` cannot be run concurrently; postgres
--       will error with "tuple concurrently updated" when that happens.
--       That's why we wrap it in a transaction-level exclusive advisory lock.
--       See http://stackoverflow.com/questions/40525684/tuple-concurrently-updated-when-creating-functions-in-postgresql-pl-pgsql/44101303
--       Update: `CREATE TABLE` is racy too, it will fail with
--         duplicate key value violates unique constraint "pg_type_typname_nsp_index"
--       when run from different sessions.
--       See https://www.postgresql.org/message-id/CA%2BTgmoZAdYVtwBfp1FL2sMZbiHCWT4UPrzRLNnX1Nb30Ku3-gg%40mail.gmail.com
--       So we put the entire thing under our advisory lock.

-- Log to make debugging hanging advisory locks easier.
DO $$ BEGIN RAISE NOTICE 'Before perform_migration creation advisory lock.'; END$$;

SELECT pg_advisory_xact_lock(4195082422317945854); -- random 64-bit signed ('bigint') lock number

DO $$ BEGIN RAISE NOTICE 'After perform_migration creation advisory lock.'; END$$;

CREATE TABLE IF not exists migrations (
  id INTEGER PRIMARY KEY,
  note TEXT
);

-- Create only if it's not there already
INSERT INTO migrations (id, note) SELECT 0, 'Initial' WHERE not exists (SELECT id FROM migrations WHERE id = 0);

-- Returns `TRUE` if we should carry on with the migration,
-- and `FALSE` if it was already run (exists in the migration table).
CREATE OR REPLACE FUNCTION perform_migration(next_migration INTEGER, note TEXT) returns BOOLEAN AS $$
DECLARE latest_migration INTEGER;
DECLARE ok BOOLEAN;
BEGIN
  -- Do nothing if it's already performed
  IF EXISTS (SELECT * FROM migrations WHERE id = next_migration) THEN
    RETURN FALSE;
  END IF;

  -- Check if the last migration is the one before next_migration
  SELECT id INTO latest_migration FROM migrations WHERE id = (SELECT MAX(id) FROM migrations);

  IF latest_migration = next_migration - 1 THEN
    INSERT INTO migrations (id, note) VALUES (next_migration, note);
    RETURN TRUE;
  ELSE
    RAISE 'Cannot perform migration % since the latest migration % performed is not its predecessor', next_migration, latest_migration;
  END IF;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  RAISE NOTICE 'Created function perform_migration.';
END$$;

COMMIT;
