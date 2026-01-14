/*
================================================================================
  ORDS User Queries - Using USER_ORDS Views
================================================================================
  Purpose: Standard queries for schema users to view their own ORDS metadata
  Execute As: Schema user (e.g., SURETY)
  
  NOTE: Column names vary between ORDS versions. This script uses SELECT *
        to show all available columns. Run 05_discover_ords_structure.sql
        to see exact column names for your ORDS version.
  
  These views are accessible without additional privileges because they:
  1. Are exposed via PUBLIC synonyms
  2. Automatically filter to show only the current schema's data
================================================================================
*/

SET LINESIZE 200
SET PAGESIZE 100

PROMPT ============================================================
PROMPT  ORDS MODULES - Current Schema
PROMPT ============================================================
PROMPT  Shows all REST modules defined in your schema
PROMPT ============================================================

SELECT * FROM user_ords_modules;

PROMPT ============================================================
PROMPT  ORDS TEMPLATES - URI Patterns
PROMPT ============================================================
PROMPT  Shows URI template patterns for each module
PROMPT ============================================================

SELECT * FROM user_ords_templates;

PROMPT ============================================================
PROMPT  ORDS HANDLERS - HTTP Methods
PROMPT ============================================================
PROMPT  Shows HTTP method handlers (GET, POST, PUT, DELETE)
PROMPT ============================================================

SELECT * FROM user_ords_handlers;

PROMPT ============================================================
PROMPT  ORDS PARAMETERS - Handler Parameters
PROMPT ============================================================
PROMPT  Shows parameters defined for handlers
PROMPT ============================================================

SELECT * FROM user_ords_parameters;

PROMPT ============================================================
PROMPT  ORDS PRIVILEGES - Security Configuration
PROMPT ============================================================
PROMPT  Shows ORDS privileges for protected resources
PROMPT ============================================================

SELECT * FROM user_ords_privileges;

PROMPT ============================================================
PROMPT  ORDS ROLES - Defined Roles
PROMPT ============================================================
PROMPT  Shows ORDS roles for authorization
PROMPT ============================================================

SELECT * FROM user_ords_roles;

PROMPT ============================================================
PROMPT  ORDS SCHEMA STATUS
PROMPT ============================================================
PROMPT  Shows if current schema is ORDS-enabled
PROMPT ============================================================

SELECT * FROM user_ords_schemas;

PROMPT ============================================================
PROMPT  AutoREST Enabled Objects
PROMPT ============================================================
PROMPT  Shows tables/views with AutoREST enabled
PROMPT ============================================================

SELECT * FROM user_ords_services;

PROMPT
PROMPT ============================================================
PROMPT  Query completed using USER_ORDS views.
PROMPT  These views only show data for the current schema.
PROMPT  
PROMPT  TIP: To see exact column names for your ORDS version, run:
PROMPT       05_discover_ords_structure.sql
PROMPT ============================================================
