#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v psql)" ]; then
    echo >&2 "Error: psql is not installed."
    exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use the following command to install it:"
    echo >&2 "    cargo install --version=0.5.7 sqlx-cli --no-default-features --features postgres"
    exit 1
fi

# Set default values for environment variables if not provided
DB_USER=${POSTGRES_USER:=postgres}
DB_PASSWORD=${POSTGRES_PASSWORD:=password}
DB_NAME=${POSTGRES_DB:=newsletter}
DB_PORT=${POSTGRES_PORT:=5432}

# Run a PostgreSQL container with Docker if SKIP_DOCKER is not set
if [[ -z "${SKIP_DOCKER}" ]]; then
    docker run \
        -e POSTGRES_USER="${DB_USER}" \
        -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
        -e POSTGRES_DB="${DB_NAME}" \
        -p "${DB_PORT}":5432 \
        -d postgres \
        postgres -N 1000
fi

# Wait for Postgres to be ready
export PGPASSWORD="${DB_PASSWORD}"
until psql -h "localhost" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q' 2>/dev/null; do
    >&2 echo "Postgres is still unavailable - sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT} - running migrations now!"

# Set up the database URL and run migrations
export DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}"
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"
