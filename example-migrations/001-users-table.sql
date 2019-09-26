BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
DO $$
  declare migration integer;
BEGIN
  migration := 1;

  IF (SELECT perform_migration(migration, 'Users table')) THEN
    raise notice 'Performing migration %', migration;

    CREATE TABLE users (
      id UUID PRIMARY KEY,
      email TEXT UNIQUE NOT NULL
    );
    CREATE UNIQUE INDEX users_email_idx ON users (email);

    -- Dummy user useful for testing.
    INSERT INTO users VALUES (
      '00000000-0000-0000-0000-1234567890ab',
      'user@example.com'
    );

  ELSE
    RAISE NOTICE 'Not performing migration %', migration;
  END IF;
END$$;
COMMIT;
