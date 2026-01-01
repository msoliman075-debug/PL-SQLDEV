# ORDS ORA-20049 Fix - Complete Solution Index

## Start Here

**New to this error?** Read: [`README_ORDS_FIX.md`](README_ORDS_FIX.md)  
**Need quick help?** Read: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)  
**Package overview?** Read: [`SOLUTION_SUMMARY.md`](SOLUTION_SUMMARY.md)

## Quick Action Guide

### I need to fix ORA-20049 right now!

**Option A - Automated (Recommended)**
```bash
sqlplus user/pass@db @fix_ords_url_mapping.sql
```
Edit the script first to set your schema name and base path.

**Option B - Manual Control**
```bash
# 1. Disable
sqlplus user/pass@db @quick_disable_enable_ords.sql

# 2. Make your changes (your custom SQL)

# 3. Re-enable
sqlplus user/pass@db @reenable_ords_schema.sql
```

**Option C - Learn First**
```bash
sqlplus user/pass@db @example_complete_workflow.sql
```

## All Files in This Package

### 📚 Documentation (Start Here)

| File | Description | Read When |
|------|-------------|-----------|
| [`README_ORDS_FIX.md`](README_ORDS_FIX.md) | Complete guide with detailed explanations | First time seeing this error |
| [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) | Quick reference card with common commands | Need fast lookup |
| [`SOLUTION_SUMMARY.md`](SOLUTION_SUMMARY.md) | Package overview and workflow guide | Understanding what's included |
| [`INDEX.md`](INDEX.md) | This file - navigation guide | Finding the right file |

### 🔧 Primary Scripts (Use These)

| File | Purpose | Complexity | Use When |
|------|---------|-----------|----------|
| [`fix_ords_url_mapping.sql`](fix_ords_url_mapping.sql) | Complete automated solution | Medium | Production fix with safety |
| [`quick_disable_enable_ords.sql`](quick_disable_enable_ords.sql) | Fast disable utility | Simple | Quick manual access |
| [`reenable_ords_schema.sql`](reenable_ords_schema.sql) | Re-enable after changes | Simple | After manual work |

### 📊 Diagnostic Scripts (Information)

| File | Purpose | Use When |
|------|---------|----------|
| [`ords_diagnostic.sql`](ords_diagnostic.sql) | View all ORDS configuration | Before changes or troubleshooting |
| [`multi_schema_management.sql`](multi_schema_management.sql) | Manage multiple schemas | Enterprise environments |

### 💾 Backup & Examples

| File | Purpose | Use When |
|------|---------|----------|
| [`backup_ords_config.sql`](backup_ords_config.sql) | Create rollback script | Before any changes |
| [`example_complete_workflow.sql`](example_complete_workflow.sql) | Full working example | Learning the process |
| [`verify_ords_fix.sql`](verify_ords_fix.sql) | Comprehensive verification | After applying fix |

### 🛠️ Utilities

| File | Purpose |
|------|---------|
| [`Fix ending in Linux`](Fix%20ending%20in%20Linux) | Fix line endings on Linux |
| [`TESTING_CHECKLIST.md`](TESTING_CHECKLIST.md) | Complete testing checklist |

## Decision Tree: Which Script Should I Use?

```
Are you fixing ORA-20049?
│
├─ Yes, and I want it automated
│  └─> Use: fix_ords_url_mapping.sql
│
├─ Yes, but I want manual control
│  ├─> Step 1: quick_disable_enable_ords.sql
│  ├─> Step 2: Make your changes
│  └─> Step 3: reenable_ords_schema.sql
│
├─ I want to learn how it works first
│  └─> Use: example_complete_workflow.sql
│
├─ I need to see current configuration
│  └─> Use: ords_diagnostic.sql
│
├─ I manage many schemas
│  └─> Use: multi_schema_management.sql
│
└─ I need to backup before changes
   └─> Use: backup_ords_config.sql
```

## Common Tasks Quick Reference

### Task 1: First Time Fix
```bash
# Read the guide
less README_ORDS_FIX.md

# Run diagnostic to understand current state
sqlplus user/pass@db @ords_diagnostic.sql

# Create backup
sqlplus user/pass@db @backup_ords_config.sql

# Run the fix (edit script first!)
sqlplus user/pass@db @fix_ords_url_mapping.sql
```

### Task 2: Quick Fix (Experienced User)
```bash
# Disable
sqlplus user/pass@db @quick_disable_enable_ords.sql

# Make changes (your SQL)

# Re-enable
sqlplus user/pass@db @reenable_ords_schema.sql
```

### Task 3: Learning the Process
```bash
# Read quick reference
less QUICK_REFERENCE.md

# Run example with detailed comments
sqlplus user/pass@db @example_complete_workflow.sql
```

### Task 4: Multiple Schemas
```bash
# Use multi-schema utility
sqlplus user/pass@db @multi_schema_management.sql
```

### Task 5: Emergency Rollback
```bash
# Run the backup created earlier
sqlplus user/pass@db @ords_backup_YOURSCHEMA.sql
```

## Script Comparison Matrix

| Feature | fix_ords | example | quick | diagnostic | backup |
|---------|----------|---------|-------|-----------|--------|
| Automated | ✓ | ✓ | ✗ | N/A | N/A |
| Error Handling | ✓✓✓ | ✓✓ | ✓ | ✓ | ✓ |
| Backup/Restore | ✓ | ✗ | ✗ | ✗ | ✓✓✓ |
| Detailed Comments | ✓ | ✓✓✓ | ✗ | ✓ | ✓ |
| Production Ready | ✓✓✓ | ✓✓ | ✓✓ | ✓✓✓ | ✓✓✓ |
| Learning Tool | ✓ | ✓✓✓ | ✗ | ✗ | ✗ |
| Interactive | ✗ | ✗ | ✓ | ✗ | ✓ |

Legend:
- ✓✓✓ = Excellent
- ✓✓ = Good  
- ✓ = Basic
- ✗ = Not applicable/available
- N/A = Not a feature of this script

## File Sizes and Complexity

| File | Lines | Complexity | Time to Run |
|------|-------|-----------|-------------|
| fix_ords_url_mapping.sql | ~200 | Medium | < 5 sec |
| example_complete_workflow.sql | ~350 | Medium | < 10 sec |
| quick_disable_enable_ords.sql | ~40 | Simple | < 1 sec |
| reenable_ords_schema.sql | ~50 | Simple | < 1 sec |
| ords_diagnostic.sql | ~100 | Simple | < 2 sec |
| backup_ords_config.sql | ~150 | Medium | < 3 sec |
| multi_schema_management.sql | ~300 | Complex | Varies |

## Prerequisites for Each Script

### All Scripts Require
- Oracle Database 19c+
- ORDS installed and configured
- EXECUTE privilege on ORDS_METADATA.ORDS
- SQL*Plus, SQL Developer, or similar client

### Specific Requirements

**fix_ords_url_mapping.sql**
- Need to edit script before running
- Must know schema name and desired base path

**example_complete_workflow.sql**
- Need to edit DEFINE variables at top
- Must know schema, module, and base path

**quick_disable_enable_ords.sql**
- Interactive - will prompt for schema name
- No editing required

**reenable_ords_schema.sql**
- Interactive - will prompt for values
- No editing required

**ords_diagnostic.sql**
- Read-only - no editing needed
- Safe to run anytime

**backup_ords_config.sql**
- Interactive - will prompt for schema name
- Creates output file

**multi_schema_management.sql**
- Most complex - read script before using
- Can modify multiple schemas

## Installation

No installation needed! Just download the files:

```bash
# Clone or download this repository
git clone <repository-url>
cd <repository-directory>

# Or copy individual files you need
```

## Quick Start Commands

### Linux/Unix
```bash
# Fix line endings first (if needed)
chmod +x "Fix ending in Linux"
./"Fix ending in Linux"

# Run a script
sqlplus username/password@database @fix_ords_url_mapping.sql
```

### Windows
```cmd
REM Run a script
sqlplus username/password@database @fix_ords_url_mapping.sql
```

### SQL Developer
1. Open script file
2. Edit variables if needed
3. Click Run Script (F5)

## Support Matrix

| Oracle DB | ORDS | Status |
|-----------|------|--------|
| 19c | 19.x | ✓ Fully Supported |
| 19c | 20.x+ | ✓ Fully Supported |
| 21c | 19.x+ | ✓ Fully Supported |
| 23c | 19.x+ | ✓ Fully Supported |

## Getting Help

### Question Type → Where to Look

**"How do I fix ORA-20049?"**
→ Read [`README_ORDS_FIX.md`](README_ORDS_FIX.md) Section "Manual Step-by-Step Process"

**"Which script should I use?"**
→ See "Decision Tree" above or [`SOLUTION_SUMMARY.md`](SOLUTION_SUMMARY.md)

**"What's my current ORDS config?"**
→ Run [`ords_diagnostic.sql`](ords_diagnostic.sql)

**"Quick command reference?"**
→ Read [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)

**"Script returned an error"**
→ Check "Troubleshooting" in [`README_ORDS_FIX.md`](README_ORDS_FIX.md)

**"Need to rollback changes"**
→ Run backup created by [`backup_ords_config.sql`](backup_ords_config.sql)

## Common Error Messages

| Error | Solution | Where to Find |
|-------|----------|---------------|
| ORA-20049 | Use any fix script | This entire package |
| "Schema not found" | Use uppercase schema name | QUICK_REFERENCE.md |
| "Insufficient privileges" | Grant EXECUTE on ORDS | README_ORDS_FIX.md |
| "Invalid base path" | Base path must start with / | QUICK_REFERENCE.md |

## Next Steps After Running Scripts

1. **Verify Changes**
   ```sql
   @ords_diagnostic.sql
   ```

2. **Test REST Endpoints**
   ```bash
   curl http://your-server:port/your-base-path/
   ```

3. **Check ORDS Logs**
   - Look for routing errors
   - Verify endpoints are accessible

4. **Update Documentation**
   - Record new base paths
   - Update API documentation

5. **Archive Backup**
   - Keep rollback script safe
   - Document changes made

## Best Practices Reminder

✓ Always backup before changes  
✓ Test in development first  
✓ Use maintenance windows  
✓ Verify after changes  
✓ Keep rollback scripts  

## Package Information

**Version**: 1.0  
**Created**: January 2026  
**Compatibility**: Oracle 19c+, ORDS 19.x+  
**Language**: Oracle PL/SQL, SQL*Plus

## File Checklist

Before you start, verify you have all files:

- [ ] README_ORDS_FIX.md
- [ ] QUICK_REFERENCE.md
- [ ] SOLUTION_SUMMARY.md
- [ ] INDEX.md (this file)
- [ ] TESTING_CHECKLIST.md
- [ ] fix_ords_url_mapping.sql
- [ ] example_complete_workflow.sql
- [ ] quick_disable_enable_ords.sql
- [ ] reenable_ords_schema.sql
- [ ] ords_diagnostic.sql
- [ ] backup_ords_config.sql
- [ ] multi_schema_management.sql
- [ ] verify_ords_fix.sql
- [ ] Fix ending in Linux

**All files present?** You're ready to fix ORA-20049! 🚀

---

**Quick Action**: If you're in a hurry, run this now:
```bash
sqlplus user/pass@db @fix_ords_url_mapping.sql
```
(Edit the script first to set your schema name!)
