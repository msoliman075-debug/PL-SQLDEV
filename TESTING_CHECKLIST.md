# ORDS ORA-20049 Fix - Testing and Validation Checklist

## Pre-Fix Checklist

Before running any fix scripts, complete these steps:

### 1. Information Gathering
- [ ] Schema name to fix: `_________________`
- [ ] Current base path: `_________________`
- [ ] New base path (if changing): `_________________`
- [ ] Module names: `_________________`
- [ ] ORDS version: `_________________`
- [ ] Oracle DB version: `_________________`

### 2. Environment Verification
- [ ] Connected to correct database
- [ ] Have appropriate privileges (EXECUTE on ORDS_METADATA.ORDS)
- [ ] Verified schema exists: `SELECT * FROM ORDS_METADATA.ORDS_SCHEMAS;`
- [ ] Identified maintenance window (if production)
- [ ] Notified users of potential downtime

### 3. Backup and Documentation
- [ ] Run `@ords_diagnostic.sql` and save output
- [ ] Run `@backup_ords_config.sql` and save generated file
- [ ] Document current REST endpoint URLs
- [ ] Export ORDS metadata (optional but recommended)
- [ ] Create rollback plan document

### 4. Script Preparation
- [ ] Downloaded all necessary scripts
- [ ] Fixed line endings (Linux: run `./Fix ending in Linux`)
- [ ] Edited `fix_ords_url_mapping.sql` with correct values
- [ ] Reviewed script comments and configuration
- [ ] Tested in development environment (if available)

## Fix Execution Checklist

### Option A: Automated Fix (Recommended)

- [ ] **Step 1**: Review edited `fix_ords_url_mapping.sql`
- [ ] **Step 2**: Execute: `@fix_ords_url_mapping.sql`
- [ ] **Step 3**: Review output for errors
- [ ] **Step 4**: Verify no exceptions raised
- [ ] **Step 5**: Confirm "Process Completed Successfully" message

### Option B: Manual Fix

- [ ] **Step 1**: Execute `@quick_disable_enable_ords.sql`
- [ ] **Step 2**: Confirm schema disabled
- [ ] **Step 3**: Make manual changes (your custom SQL)
- [ ] **Step 4**: Verify changes with SELECT statements
- [ ] **Step 5**: Execute `@reenable_ords_schema.sql`
- [ ] **Step 6**: Confirm schema re-enabled

## Post-Fix Verification Checklist

### 1. Database-Level Verification

Run the verification script:
- [ ] Execute: `@verify_ords_fix.sql`
- [ ] All critical tests pass: `[PASS]`
- [ ] Review any warnings: `[WARN]`
- [ ] Address any failures: `[FAIL]`

Manual verification queries:
```sql
-- Schema is enabled
- [ ] SELECT schema_name, is_enabled FROM ORDS_METADATA.ORDS_SCHEMAS 
      WHERE schema_name = 'YOUR_SCHEMA';
      -- Result should show is_enabled = 'Y'

-- Modules configured correctly
- [ ] SELECT m.name, m.base_path, m.status 
      FROM ORDS_METADATA.ORDS_MODULES m
      JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
      WHERE s.schema_name = 'YOUR_SCHEMA';
      -- Verify base paths are correct

-- Templates exist
- [ ] SELECT COUNT(*) FROM ORDS_METADATA.ORDS_TEMPLATES t
      JOIN ORDS_METADATA.ORDS_MODULES m ON t.module_id = m.id
      JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
      WHERE s.schema_name = 'YOUR_SCHEMA';
      -- Should return > 0
```

### 2. ORDS Service Verification

- [ ] ORDS service is running
- [ ] No errors in ORDS logs
- [ ] ORDS can connect to database
- [ ] Schema appears in ORDS metadata

Check ORDS logs:
```bash
# Location varies by installation
# Common locations:
- [ ] tail -f $ORDS_HOME/logs/ords.log
- [ ] Check application server logs (if using Tomcat/WebLogic)
```

### 3. REST Endpoint Testing

#### Test Method 1: Command Line (curl)
```bash
# Test base path
- [ ] curl -i http://your-server:port/base-path/

# Test specific endpoint
- [ ] curl -i http://your-server:port/base-path/endpoint/

# Expected: HTTP 200 or 404 (not connection refused)
```

#### Test Method 2: Browser
- [ ] Open: `http://your-server:port/base-path/`
- [ ] Verify: No 503 or connection errors
- [ ] Test: Known endpoint returns expected data
- [ ] Check: JSON/XML response format correct

#### Test Method 3: REST Client (Postman/Insomnia)
- [ ] Import existing endpoint collection
- [ ] Update base URLs if changed
- [ ] Run test collection
- [ ] Verify all endpoints respond correctly
- [ ] Check response times acceptable

### 4. Functional Testing

For each REST endpoint:
- [ ] **GET** requests return data
- [ ] **POST** requests create records (if applicable)
- [ ] **PUT** requests update records (if applicable)
- [ ] **DELETE** requests remove records (if applicable)
- [ ] Authentication works (if required)
- [ ] Authorization rules enforced
- [ ] Error handling working properly

### 5. Performance Verification

- [ ] Response times acceptable
- [ ] No timeout errors
- [ ] Multiple concurrent requests handled
- [ ] Database connections released properly
- [ ] No memory leaks in ORDS process

### 6. Security Verification

- [ ] Authentication required where expected
- [ ] Unauthorized access blocked
- [ ] HTTPS working (if configured)
- [ ] CORS headers correct (if applicable)
- [ ] No sensitive data exposed in errors

## Rollback Checklist (If Needed)

If problems occur:

### Immediate Rollback
- [ ] Execute backup script: `@ords_backup_SCHEMANAME.sql`
- [ ] Verify schema status restored
- [ ] Test original endpoints work
- [ ] Document what went wrong
- [ ] Plan corrective action

### Manual Rollback
```sql
- [ ] BEGIN
        ORDS.DISABLE_SCHEMA(p_schema => 'YOUR_SCHEMA');
      END;
      /

- [ ] -- Restore original configuration
      -- (from documentation or backup)

- [ ] BEGIN
        ORDS.ENABLE_SCHEMA(
          p_schema => 'YOUR_SCHEMA',
          p_url_mapping_pattern => '/original/path/'
        );
      END;
      /

- [ ] -- Verify restoration
      SELECT * FROM ORDS_METADATA.ORDS_SCHEMAS 
      WHERE schema_name = 'YOUR_SCHEMA';
```

## Documentation Checklist

After successful fix:

- [ ] Update API documentation with new base paths
- [ ] Update internal wiki/knowledge base
- [ ] Document any configuration changes
- [ ] Update monitoring tools (if base paths changed)
- [ ] Notify development team of changes
- [ ] Update deployment procedures
- [ ] Archive backup scripts in version control
- [ ] Update runbook/procedures

## Communication Checklist

### Pre-Fix
- [ ] Notify stakeholders of maintenance window
- [ ] Alert operations team
- [ ] Post maintenance notice (if applicable)
- [ ] Prepare status update template

### During Fix
- [ ] Update status in ticket/incident system
- [ ] Keep operations team informed
- [ ] Document any issues encountered

### Post-Fix
- [ ] Send completion notification
- [ ] Update ticket/incident with results
- [ ] Share verification results
- [ ] Schedule follow-up review (24 hours later)

## Troubleshooting Checklist

If verification fails:

### Schema Not Enabled
- [ ] Check if disable/enable completed
- [ ] Review error messages in output
- [ ] Verify no transaction rollback occurred
- [ ] Manually enable: `EXEC ORDS.ENABLE_SCHEMA(p_schema => 'YOUR_SCHEMA');`

### Endpoints Not Accessible
- [ ] Verify ORDS service running
- [ ] Check ORDS can connect to database
- [ ] Verify firewall/network allows connections
- [ ] Check ORDS logs for errors
- [ ] Confirm base path is correct

### Wrong Base Path
- [ ] Disable schema
- [ ] Re-enable with correct path
- [ ] Clear any ORDS caches
- [ ] Restart ORDS if needed (rare)

### Performance Issues
- [ ] Check database performance
- [ ] Review ORDS connection pool settings
- [ ] Verify adequate system resources
- [ ] Check for long-running queries

## Sign-Off Checklist

Final approval before marking complete:

### Technical Sign-Off
- [ ] All verification tests pass
- [ ] REST endpoints accessible
- [ ] Performance acceptable
- [ ] No errors in logs
- [ ] Backup scripts archived

### Business Sign-Off
- [ ] API consumers notified
- [ ] Documentation updated
- [ ] No business impact reported
- [ ] SLA/SLO maintained

### Compliance Sign-Off
- [ ] Change management record complete
- [ ] Audit trail documented
- [ ] Security verification passed
- [ ] Backup retention policy followed

## Success Criteria

Mark complete when ALL of these are true:

✓ Schema is enabled (`is_enabled = 'Y'`)  
✓ Modules have valid base paths (start with `/`)  
✓ Templates exist and are published  
✓ REST endpoints return expected responses  
✓ No errors in ORDS or database logs  
✓ Performance is acceptable  
✓ Documentation is updated  
✓ Backup scripts are archived  

## Notes Section

Use this section to record observations:

```
Date: _______________
Time Started: _______________
Time Completed: _______________

Issues Encountered:
_________________________________
_________________________________
_________________________________

Deviations from Plan:
_________________________________
_________________________________
_________________________________

Lessons Learned:
_________________________________
_________________________________
_________________________________

Follow-Up Items:
_________________________________
_________________________________
_________________________________
```

## Quick Reference

### Verification Commands
```sql
-- Schema status
@verify_ords_fix.sql

-- Current configuration
@ords_diagnostic.sql

-- Test endpoint
SELECT 'curl http://server:port' || base_path 
FROM ORDS_METADATA.ORDS_MODULES m
JOIN ORDS_METADATA.ORDS_SCHEMAS s ON m.schema_id = s.id
WHERE s.schema_name = 'YOUR_SCHEMA';
```

### Emergency Contacts
- DBA: _______________
- ORDS Admin: _______________
- Application Owner: _______________
- On-Call: _______________

---

**Remember**: It's better to take extra time for verification than to rush and miss issues!

**Final Check**: Did you update the documentation? ☑️
