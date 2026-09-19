#!/bin/bash

set -e

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "transfer_system" \
  --file "/sql/01_oltp_schema.sql"

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "transfer_system" \
  --file "/sql/02_staging_schema.sql"