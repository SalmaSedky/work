# Classification ID System - Quick Start Guide

## What You Need

You asked for help converting your transactional type classification from text-based to ID-based using CL_SCM and CL_CV tables. Here's everything you need!

---

## 🚀 Quick Start (3 Steps)

### Step 1: Create the Tables and Load Data

Run this file to create tables and insert all 7 classifications:

```bash
@CLASSIFICATION_ID_SETUP.sql
```

This creates:
- `dev_sor.ADMIN.CL_SCM` table (Classification Schema)
- `dev_sor.ADMIN.CL_CV` table (Classification Values)
- Inserts "Portal Transaction Type" schema
- Inserts 7 classification values with auto-generated IDs

### Step 2: Use the ID-based Query

Your original CASE statement pattern has been converted to use ID lookups:

```sql
-- Use this query in your ETL/DWH job
@TRANSACTIONAL_TYPE_WITH_IDS.sql
```

This returns `PRTL_SLS_TP_ID` (BIGINT) instead of text strings.

### Step 3: Verify It Works

Run the verification queries at the bottom of `CLASSIFICATION_ID_SETUP.sql` to confirm:
- All 7 classifications were inserted
- IDs were generated correctly
- Lookups are working

---

## 📋 The 7 Classifications

| ID | Classification Name | Code | When Used |
|----|---------------------|------|-----------|
| 1 | Business Ultimate | BUS_ULT | PRODUCT_TYPE IN ('BUlitmate', 'Business') |
| 2 | MNP | MNP | IS_MNP = 'Y' |
| 3 | New Prepaid | NEW_PREPAID | NEW_ACCOUNT_ACTION + Prepaid |
| 4 | New Postpaid | NEW_POSTPAID | NEW_ACCOUNT_ACTION + Postpaid |
| 5 | Migration | MIGRATION | MIGRATION_ACTION |
| 6 | Portal Reregistration | PORTAL_REREG | REREGISTRATION_ACTION |
| 7 | Elife | ELIFE | PRODUCT_TYPE = 'Fixed' |

---

## 🔧 What Was Fixed

Your original code had these issues that were corrected:

### Issue 1: Swapped Postpaid/Prepaid ❌→✅
```sql
-- YOUR ORIGINAL (WRONG):
WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'New Prepaid'  ❌
WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'New Postpaid'  ❌

-- CORRECTED:
WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'New Postpaid'  ✅
WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'New Prepaid'   ✅
```

### Issue 2: Added Business Ultimate Priority
Your code didn't handle Business/BUlitmate types first, so they would fall through to other rules. Added as Rule 0 (highest priority after MNP logic dictates it should be before MNP).

---

## 💡 How to Use the ID Lookup Pattern

### Your Example Pattern:
```sql
(SELECT B.CL_CV_ID 
 FROM dev_Sor.ADMIN.CL_SCM A, 
      dev_sor.ADMIN.CL_CV B
 WHERE A.CL_SCM_NM = 'Portal Transaction Type'
   AND A.CL_SCM_ID = B.CL_SCM_ID
   AND B.CL_NM = 'New Prepaid'       
) :: BIGINT AS PRTL_SLS_TP_ID
```

### Applied to All Rules:
```sql
CASE
    -- Rule 0: Business Ultimate
    WHEN PRODUCT_TYPE IN('BUlitmate','Business') THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Business Ultimate' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 1: MNP Flag takes highest priority
    WHEN IS_MNP = 'Y' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'MNP' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 2: New Postpaid Account (FIXED: was 'New Prepaid')
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'New Postpaid' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 3: New Prepaid Account (FIXED: was 'New Postpaid')
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'New Prepaid' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 4: Migration Action
    WHEN ACTON = 'MIGRATION_ACTION' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Migration' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 5: Reregistration Action (uses 'Portal Reregistration' as in your example)
    WHEN ACTON = 'REREGISTRATION_ACTION' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Portal Reregistration' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Rule 6: Fixed Product Type (uses 'Elife' as in your example)
    WHEN PRODUCT_TYPE = 'Fixed' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Elife' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
    
    -- Default: Return NULL
    ELSE NULL
END AS PRTL_SLS_TP_ID
```

---

## 📊 Example Output

### Input Data:
```
IS_MNP | PRODUCT_TYPE | ACTON
-------|--------------|------------------------
N      | Business     | NEW_ACCOUNT_ACTION
Y      | Prepaid      | NEW_ACCOUNT_ACTION
N      | Postpaid     | NEW_ACCOUNT_ACTION
N      | Prepaid      | NEW_ACCOUNT_ACTION
N      | Postpaid     | MIGRATION_ACTION
N      | Fixed        | MANAGE_SERVICE_ACTION
```

### Output with IDs:
```
IS_MNP | PRODUCT_TYPE | ACTON                  | PRTL_SLS_TP_ID | Classification
-------|--------------|------------------------|----------------|-------------------
N      | Business     | NEW_ACCOUNT_ACTION     | 1              | Business Ultimate
Y      | Prepaid      | NEW_ACCOUNT_ACTION     | 2              | MNP
N      | Postpaid     | NEW_ACCOUNT_ACTION     | 4              | New Postpaid
N      | Prepaid      | NEW_ACCOUNT_ACTION     | 3              | New Prepaid
N      | Postpaid     | MIGRATION_ACTION       | 5              | Migration
N      | Fixed        | MANAGE_SERVICE_ACTION  | 7              | Elife
```

---

## 🎯 Performance Tip

For better performance with large datasets, use the CTE version from `TRANSACTIONAL_TYPE_WITH_IDS.sql`:

```sql
WITH classification_ids AS (
    -- Pre-load all classification IDs once
    SELECT cv.CL_NM, cv.CL_CV_ID
    FROM dev_sor.ADMIN.CL_SCM scm
    JOIN dev_sor.ADMIN.CL_CV cv ON scm.CL_SCM_ID = cv.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type'
      AND cv.ACTIVE_FLAG = 'Y'
)
SELECT 
    CASE
        WHEN PRODUCT_TYPE IN('BUlitmate','Business') THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'Business Ultimate')
        WHEN IS_MNP = 'Y' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'MNP')
        -- ... etc
    END AS PRTL_SLS_TP_ID
FROM your_data
```

This loads the IDs once instead of for every row.

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| **CLASSIFICATION_ID_SETUP.sql** | Run this first - creates tables and loads data |
| **TRANSACTIONAL_TYPE_WITH_IDS.sql** | Your main query - use this in ETL jobs |
| **CLASSIFICATION_ID_MAPPING.md** | Full documentation - read for details |
| **README.md** | Project overview - updated with new features |

---

## ✅ Checklist

- [ ] Run `CLASSIFICATION_ID_SETUP.sql` to create tables
- [ ] Verify 7 classifications were inserted (check with verification queries)
- [ ] Review `TRANSACTIONAL_TYPE_WITH_IDS.sql` patterns
- [ ] Choose implementation pattern (subquery, CTE, or full query)
- [ ] Test with sample data
- [ ] Integrate into your ETL/DWH job
- [ ] Update downstream reports to use PRTL_SLS_TP_ID

---

## 🆘 Troubleshooting

**Problem**: Tables already exist  
**Solution**: Drop and recreate, or modify script to use CREATE OR REPLACE

**Problem**: IDs are different than shown in examples  
**Solution**: IDs auto-increment, so exact values may vary. Use the lookup pattern, not hardcoded IDs.

**Problem**: Lookup returns NULL  
**Solution**: Check ACTIVE_FLAG = 'Y' and classification name spelling

**Problem**: Performance is slow  
**Solution**: Use CTE pattern or add indexes (see CLASSIFICATION_ID_MAPPING.md)

---

## 📞 Need Help?

See detailed documentation in:
- [CLASSIFICATION_ID_MAPPING.md](CLASSIFICATION_ID_MAPPING.md) - Complete guide
- [TRANSACTIONAL_TYPE_WITH_IDS.sql](TRANSACTIONAL_TYPE_WITH_IDS.sql) - Query examples
- [CLASSIFICATION_ID_SETUP.sql](CLASSIFICATION_ID_SETUP.sql) - Table setup

---

**Version**: 1.0  
**Date**: 2026-02-03  
**Status**: Production Ready ✅
