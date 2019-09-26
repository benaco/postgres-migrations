# postgres-migrations

A simple and safe SQL-based migration system.

Stores the information of which migrations were already run in a table.

Provides a function `perform_migration(N, 'Description text')` to be used like this:

```sql
migration := 42;
IF (SELECT perform_migration(migration, 'Add address to users table')) THEN
  RAISE NOTICE 'Performing migration %', migration;

  -- Migration commands here
  ALTER TABLE users ADD COLUMN address TEXT; -- nullable

ELSE
  RAISE NOTICE 'Not performing migration %', migration;
END IF;
```

(See `example-migrations/` for full examples.)

A common usage pattern is that at the startup of your application
(e.g. its web-server), all migrations are run in order.
As shown above, migrations that were already run are automatically skipped.

All migrations are wrapped in transactions with `SERIALIZABLE` transaction
level, ensuring that any DDL or data changes done by the migrations
are fully rolled back if the migration fails.


## Example usage

### Create and run database

```bash
# Put postgres binaries on PATH (adjust for your distro's path)
export PATH=/usr/lib/postgresql/9.5/bin:$PATH

rm -rf .postgres-db  # wipe DB
initdb -D .postgres-db
echo "unix_socket_directories = ''" >> .postgres-db/postgresql.conf

postgres -D .postgres-db  # start DB on this shell
```

### Run migrations

The `run-migrations.sql` file includes all the `example-migrations/` in order. Run it with `psql`:

```bash
psql --quiet --host localhost --dbname postgres --file run-migrations.sql
```

You will see output including like

```
NOTICE:  Performing migration 1
NOTICE:  Performing migration 2
```

on the first run, and on subsequent runs see:

```
NOTICE:  Not performing migration 1
NOTICE:  Not performing migration 2
```

In your application you will likely want to run `run-migrations.sql` via your programming language's postgres library than via `psql`.


### Adding new migrations

Simply create a new file in `example-migrations/`, and include it in `run-migrations.sql`.

Don't forget to bump the migration number in the migration (like `migration := 42`).


## License

MIT-licensed
