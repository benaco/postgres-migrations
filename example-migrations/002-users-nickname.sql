BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
DO $$
  declare migration integer;
BEGIN
  migration := 2;

  IF (SELECT perform_migration(migration, 'User nick names')) THEN
    raise notice 'Performing migration %', migration;

    ALTER TABLE users ADD COLUMN nickname TEXT NULL;

  ELSE
    RAISE NOTICE 'Not performing migration %', migration;
  END IF;
END$$;
COMMIT;
