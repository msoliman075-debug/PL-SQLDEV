# REST Services

This directory contains SQL scripts to define ORDS REST services.

## Installation

1. Connect to the target Oracle database schema (e.g., `SURETY`) using SQLcl or SQL Developer.
2. Run the SQL scripts in this directory.

## Modules

### Surety Module (`modules/surety.sql`)

Defines the `surety` module with the following endpoints:

- `POST /ords/surety/surety/upload_policy`: Handler for uploading policies. Currently implements a stub that returns 200 OK.
