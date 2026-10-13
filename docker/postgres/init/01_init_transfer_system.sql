\set ON_ERROR_STOP on

\connect transfer_system

\i /sql/01_oltp_schema.sql
\i /sql/02_staging_schema.sql
