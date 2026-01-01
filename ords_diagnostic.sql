-- ============================================================================
-- ORDS Configuration Diagnostic Script
-- ============================================================================
-- This script provides detailed information about your ORDS setup
-- Run this to understand current configuration before making changes
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 1000
SET VERIFY OFF

PROMPT ========================================
PROMPT ORDS Configuration Diagnostic Report
PROMPT ========================================
PROMPT

PROMPT ----------------------------------------
PROMPT 1. ORDS Enabled Schemas
PROMPT ----------------------------------------
SELECT 
    schema_name,
    is_enabled,
    parsing_schema,
    has_credentials
FROM ORDS_METADATA.ORDS_SCHEMAS
ORDER BY schema_name;

PROMPT
PROMPT ----------------------------------------
PROMPT 2. ORDS Modules and Base Paths
PROMPT ----------------------------------------
SELECT 
    s.schema_name,
    m.name as module_name,
    m.base_path,
    m.status,
    m.items_per_page
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
ORDER BY s.schema_name, m.name;

PROMPT
PROMPT ----------------------------------------
PROMPT 3. ORDS Templates (URL Patterns)
PROMPT ----------------------------------------
SELECT 
    s.schema_name,
    m.name as module_name,
    t.uri_template,
    t.priority
FROM ORDS_METADATA.ORDS_TEMPLATES t
JOIN ORDS_METADATA.ORDS_MODULES m ON t.module_id = m.id
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
ORDER BY s.schema_name, m.name, t.priority;

PROMPT
PROMPT ----------------------------------------
PROMPT 4. ORDS Privileges
PROMPT ----------------------------------------
SELECT 
    name,
    label,
    description
FROM ORDS_METADATA.ORDS_PRIVILEGES
ORDER BY name;

PROMPT
PROMPT ----------------------------------------
PROMPT 5. Schema Status Summary
PROMPT ----------------------------------------
SELECT 
    COUNT(*) as total_schemas,
    SUM(CASE WHEN is_enabled = 'Y' THEN 1 ELSE 0 END) as enabled_schemas,
    SUM(CASE WHEN is_enabled = 'N' THEN 1 ELSE 0 END) as disabled_schemas
FROM ORDS_METADATA.ORDS_SCHEMAS;

PROMPT
PROMPT ========================================
PROMPT Diagnostic Report Complete
PROMPT ========================================
