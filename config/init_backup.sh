#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the required environment variables are set
if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL environment variable is not set."
  exit 1
fi

if [ -z "$SCHEMA_EXTENSION" ]; then
  echo "Error: SCHEMA_EXTENSION environment variable is not set."
  exit 1
fi

if [ -z "$SERVICE" ]; then
  echo "Error: SERVICE environment variable is not set."
  exit 1
fi

# Temporary dump file in the current location
SQL_DUMP_PATH="./temp_schema_dump.sql"

# Compute the new schema name
NEW_SCHEMA="${SERVICE}_${SCHEMA_EXTENSION}"

# Check if the new schema already exists
schema_exists=$(psql "$DATABASE_URL" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = '$NEW_SCHEMA');")

if [ "$schema_exists" = "t" ]; then
  echo "Error: Schema '$NEW_SCHEMA' already exists. Exiting."
  exit 1
fi

# Dump the existing schema into a SQL file
echo "Dumping existing schema '$SERVICE' to file '$SQL_DUMP_PATH'..."
pg_dump "$DATABASE_URL" --schema="$SERVICE" --no-owner --no-acl > "$SQL_DUMP_PATH"

# Connect to PostgreSQL and create the new schema
echo "Creating schema '$NEW_SCHEMA'..."
psql "$DATABASE_URL" -c "CREATE SCHEMA IF NOT EXISTS \"$NEW_SCHEMA\";"

# Restore the SQL dump into the new schema
echo "Restoring SQL dump into schema '$NEW_SCHEMA'..."
sed "s/\b$SERVICE\b/$NEW_SCHEMA/g" "$SQL_DUMP_PATH" | psql "$DATABASE_URL"

# Delete the temporary dump file
echo "Cleaning up temporary dump file..."
rm -f "$SQL_DUMP_PATH"

echo "Schema '$NEW_SCHEMA' and data restored successfully."
