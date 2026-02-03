# Classification ID Mapping Documentation

## Overview
This document describes the classification ID lookup system using CL_SCM (Classification Schema) and CL_CV (Classification Values) tables to assign Portal Transaction Type IDs.

---

## Table Structure

### CL_SCM (Classification Schema)
Defines classification categories/schemas.

| Column | Type | Description |
|--------|------|-------------|
| CL_SCM_ID | BIGINT | Primary key, auto-increment |
| CL_SCM_NM | VARCHAR(255) | Schema name (e.g., 'Portal Transaction Type') |
| CL_SCM_DESC | VARCHAR(1000) | Schema description |
| CREATED_DATE | TIMESTAMP | Creation timestamp |
| CREATED_BY | VARCHAR(100) | Creator user |
| UPDATED_DATE | TIMESTAMP | Last update timestamp |
| UPDATED_BY | VARCHAR(100) | Last updater user |
| ACTIVE_FLAG | CHAR(1) | 'Y' or 'N' |

### CL_CV (Classification Values)
Defines specific classification values within each schema.

| Column | Type | Description |
|--------|------|-------------|
| CL_CV_ID | BIGINT | Primary key, auto-increment |
| CL_SCM_ID | BIGINT | Foreign key to CL_SCM |
| CL_NM | VARCHAR(255) | Classification name |
| CL_DESC | VARCHAR(1000) | Classification description |
| CL_CODE | VARCHAR(50) | Classification code |
| DISPLAY_ORDER | INT | Display order |
| CREATED_DATE | TIMESTAMP | Creation timestamp |
| CREATED_BY | VARCHAR(100) | Creator user |
| UPDATED_DATE | TIMESTAMP | Last update timestamp |
| UPDATED_BY | VARCHAR(100) | Last updater user |
| ACTIVE_FLAG | CHAR(1) | 'Y' or 'N' |

---

## Portal Transaction Type Classifications

### Schema Details
- **CL_SCM_NM**: `'Portal Transaction Type'`
- **CL_SCM_DESC**: `'Classification schema for portal transaction types including MNP, new accounts, migrations, and other transaction categories'`

### Classification Values

| CL_CV_ID | CL_NM | CL_CODE | Description | Display Order |
|----------|-------|---------|-------------|---------------|
| 1 | Business Ultimate | BUS_ULT | Business Ultimate product type for BUlitmate and Business product categories | 1 |
| 2 | MNP | MNP | Mobile Number Portability - customer porting number from another provider | 2 |
| 3 | New Prepaid | NEW_PREPAID | New prepaid account activation without number portability | 3 |
| 4 | New Postpaid | NEW_POSTPAID | New postpaid account activation without number portability | 4 |
| 5 | Migration | MIGRATION | Customer migrating between plans or services | 5 |
| 6 | Portal Reregistration | PORTAL_REREG | Re-registration of existing customer or SIM through portal | 6 |
| 7 | Elife | ELIFE | Fixed broadband/internet services (eLife product line) | 7 |

**Note**: The actual CL_CV_ID values may vary depending on database sequence. Use the lookup pattern to get current IDs.

---

## Business Logic to Classification Mapping

### Priority-Based Classification Rules

| Priority | Condition | Classification | CL_CV_ID | CL_NM |
|----------|-----------|----------------|----------|-------|
| 0 | `PRODUCT_TYPE IN ('BUlitmate', 'Business')` | Business Ultimate | 1 | Business Ultimate |
| 1 | `IS_MNP = 'Y'` | MNP | 2 | MNP |
| 2 | `ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid'` | New Postpaid | 4 | New Postpaid |
| 3 | `ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid'` | New Prepaid | 3 | New Prepaid |
| 4 | `ACTON = 'MIGRATION_ACTION'` | Migration | 5 | Migration |
| 5 | `ACTON = 'REREGISTRATION_ACTION'` | Reregistration | 6 | Portal Reregistration |
| 6 | `PRODUCT_TYPE = 'Fixed'` | eLife | 7 | Elife |
| 7 | None of above | Unclassified | NULL | NULL |

**Important**: Rules are evaluated in priority order. First match wins.

---

## Sample Data with Expected IDs

Based on sample transaction data:

| IS_MNP | PRODUCT_TYPE | ACTON | PRTL_SLS_TP_ID | Classification Name |
|--------|--------------|-------|----------------|---------------------|
| N | Business | TRANSFER_OF_OWNERSHIP_ACTION | 1 | Business Ultimate |
| N | Business | NEW_ACCOUNT_ACTION | 1 | Business Ultimate |
| N | BUlitmate | REREGISTRATION_ACTION | 1 | Business Ultimate |
| N | Postpaid | AUCTION_ACTION | NULL | (Unclassified) |
| N | Postpaid | NEW_ACCOUNT_ACTION | 4 | New Postpaid |
| N | Postpaid | MIGRATION_ACTION | 5 | Migration |
| N | Postpaid | REREGISTRATION_ACTION | 6 | Portal Reregistration |
| N | Fixed | MANAGE_SERVICE_ACTION | 7 | Elife |
| N | Fixed | NEW_ACCOUNT_ACTION | 7 | Elife |
| N | Prepaid | CESSATION_ACTION | NULL | (Unclassified) |
| N | Prepaid | NEW_ACCOUNT_ACTION | 3 | New Prepaid |
| N | Prepaid | REREGISTRATION_ACTION | 6 | Portal Reregistration |
| Y | Prepaid | NEW_ACCOUNT_ACTION | 2 | MNP |
| Y | Business | NEW_ACCOUNT_ACTION | 2 | MNP |
| Y | Postpaid | NEW_ACCOUNT_ACTION | 2 | MNP |

---

## ID Lookup Pattern

### Basic Pattern (Subquery)

```sql
(SELECT B.CL_CV_ID 
 FROM dev_sor.ADMIN.CL_SCM A, 
      dev_sor.ADMIN.CL_CV B
 WHERE A.CL_SCM_NM = 'Portal Transaction Type'
   AND A.CL_SCM_ID = B.CL_SCM_ID
   AND B.CL_NM = 'New Prepaid'
   AND B.ACTIVE_FLAG = 'Y'
) :: BIGINT
```

### Alternative Pattern (JOIN)

```sql
WITH classification_ids AS (
    SELECT 
        cv.CL_NM,
        cv.CL_CV_ID
    FROM dev_sor.ADMIN.CL_SCM scm
    JOIN dev_sor.ADMIN.CL_CV cv ON scm.CL_SCM_ID = cv.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type'
      AND cv.ACTIVE_FLAG = 'Y'
)
SELECT 
    (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'New Prepaid')
```

### Using Helper Function

```sql
SELECT dev_sor.ADMIN.GET_CLASSIFICATION_ID('Portal Transaction Type', 'New Prepaid');
```

---

## Complete CASE Statement with ID Lookups

```sql
CASE
    -- Rule 0: Business Ultimate
    WHEN PRODUCT_TYPE IN ('BUlitmate', 'Business') THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Business Ultimate'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 1: MNP
    WHEN IS_MNP = 'Y' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'MNP'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 2: New Postpaid
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'New Postpaid'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 3: New Prepaid
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'New Prepaid'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 4: Migration
    WHEN ACTON = 'MIGRATION_ACTION' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Migration'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 5: Portal Reregistration
    WHEN ACTON = 'REREGISTRATION_ACTION' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Portal Reregistration'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Rule 6: Elife
    WHEN PRODUCT_TYPE = 'Fixed' THEN 
        (SELECT B.CL_CV_ID 
         FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'Elife'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    
    -- Default
    ELSE NULL
END AS PRTL_SLS_TP_ID
```

---

## Key Differences from Original Implementation

### Original (String-based)
```sql
CASE
    WHEN IS_MNP = 'Y' THEN 'MNP'
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'new postpaid'
    ...
END AS transactional_type
```

### New (ID-based)
```sql
CASE
    WHEN IS_MNP = 'Y' THEN 
        (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
         WHERE A.CL_SCM_NM = 'Portal Transaction Type'
           AND A.CL_SCM_ID = B.CL_SCM_ID
           AND B.CL_NM = 'MNP'
           AND B.ACTIVE_FLAG = 'Y'
        ) :: BIGINT
    ...
END AS PRTL_SLS_TP_ID
```

### Benefits of ID-based Approach
1. **Data Integrity**: Foreign key relationships ensure valid IDs
2. **Centralized Management**: Update classification names in one place
3. **Audit Trail**: Track when classifications were created/modified
4. **Flexibility**: Easy to add new classifications without code changes
5. **Standardization**: Same ID used across all systems
6. **Performance**: JOINs on integers faster than string comparisons

---

## Corrections from User's Example

The user's problem statement had some inconsistencies that were corrected:

| User's Code | Corrected To | Reason |
|-------------|--------------|--------|
| `WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'New Prepaid'` | `'New Postpaid'` | Postpaid should map to New Postpaid, not New Prepaid |
| `WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'New Postpaid'` | `'New Prepaid'` | Prepaid should map to New Prepaid, not New Postpaid |

---

## Validation Queries

### Verify All Classifications Exist
```sql
SELECT 
    cv.CL_CV_ID,
    scm.CL_SCM_NM,
    cv.CL_NM,
    cv.CL_CODE,
    cv.DISPLAY_ORDER,
    cv.ACTIVE_FLAG
FROM dev_sor.ADMIN.CL_CV cv
JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
WHERE scm.CL_SCM_NM = 'Portal Transaction Type'
ORDER BY cv.DISPLAY_ORDER;
```

### Test ID Lookup for Each Classification
```sql
-- Business Ultimate
SELECT 'Business Ultimate' AS classification,
       (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
        WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
          AND B.CL_NM = 'Business Ultimate' AND B.ACTIVE_FLAG = 'Y') AS CL_CV_ID
UNION ALL
-- MNP
SELECT 'MNP',
       (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
        WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
          AND B.CL_NM = 'MNP' AND B.ACTIVE_FLAG = 'Y')
UNION ALL
-- Add remaining classifications...
```

### Verify Query Results Include Classification Names
```sql
SELECT 
    X.PRTL_SLS_TP_ID,
    cv.CL_NM AS classification_name,
    COUNT(*) AS record_count
FROM (
    -- Your main query here
) X
LEFT JOIN dev_sor.ADMIN.CL_CV cv ON X.PRTL_SLS_TP_ID = cv.CL_CV_ID
GROUP BY X.PRTL_SLS_TP_ID, cv.CL_NM
ORDER BY X.PRTL_SLS_TP_ID;
```

---

## Maintenance Guidelines

### Adding a New Classification
1. INSERT new row into CL_CV:
   ```sql
   INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
   SELECT 
       (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
       'New Classification Name',
       'Description',
       'CODE',
       8,  -- Next display order
       'USERNAME',
       'Y';
   ```

2. Add WHEN clause to CASE statement in queries
3. Update documentation
4. Test with sample data

### Modifying a Classification Name
1. UPDATE CL_CV table:
   ```sql
   UPDATE dev_sor.ADMIN.CL_CV 
   SET CL_NM = 'Updated Name',
       UPDATED_DATE = CURRENT_TIMESTAMP,
       UPDATED_BY = 'USERNAME'
   WHERE CL_CV_ID = ?;
   ```

2. Update CASE statement CL_NM references
3. Update documentation
4. Validate existing data

### Deactivating a Classification
```sql
UPDATE dev_sor.ADMIN.CL_CV 
SET ACTIVE_FLAG = 'N',
    UPDATED_DATE = CURRENT_TIMESTAMP,
    UPDATED_BY = 'USERNAME'
WHERE CL_CV_ID = ?;
```

**Note**: Queries filter on `ACTIVE_FLAG = 'Y'`, so deactivated classifications will return NULL.

---

## Performance Considerations

### For Large Datasets
1. **Use CTE**: Pre-load classification IDs into CTE
2. **Create Indexed View**: Materialize classification lookups
3. **Cache Results**: Store PRTL_SLS_TP_ID in staging table
4. **Use Helper Function**: Encapsulate lookup logic

### Indexing Recommendations
```sql
-- Index on CL_SCM
CREATE INDEX IDX_CL_SCM_NAME ON dev_sor.ADMIN.CL_SCM(CL_SCM_NM, ACTIVE_FLAG);

-- Index on CL_CV
CREATE INDEX IDX_CL_CV_SCHEMA_NAME ON dev_sor.ADMIN.CL_CV(CL_SCM_ID, CL_NM, ACTIVE_FLAG);
CREATE INDEX IDX_CL_CV_CODE ON dev_sor.ADMIN.CL_CV(CL_CODE, ACTIVE_FLAG);
```

---

## Related Files

- **Setup Script**: [CLASSIFICATION_ID_SETUP.sql](CLASSIFICATION_ID_SETUP.sql)
- **Query with IDs**: [TRANSACTIONAL_TYPE_WITH_IDS.sql](TRANSACTIONAL_TYPE_WITH_IDS.sql)
- **Original Query**: [TRANSACTIONAL_TYPE_QUERY.sql](TRANSACTIONAL_TYPE_QUERY.sql)
- **Original Mapping**: [TRANSACTIONAL_TYPE_MAPPING.md](TRANSACTIONAL_TYPE_MAPPING.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-03 | Initial implementation with CL_SCM/CL_CV ID lookup system |

---

## Support

For questions or issues:
1. Verify classifications exist: Query CL_CV table
2. Test ID lookup: Run individual SELECT subqueries
3. Check ACTIVE_FLAG: Ensure classifications are active
4. Review audit trail: Check CREATED_DATE, UPDATED_DATE in CL_CV
5. Validate business logic: Ensure CASE conditions match requirements
