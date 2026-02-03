# Transactional Type Query - Expected Results

## Query Output Example

Based on the sample data provided, here are the expected results when running the transactional_type query:

### Complete Output with All Columns

```
IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type
-------|--------------|-------------------------------|-------------------
Y      | Prepaid      | NEW_ACCOUNT_ACTION            | MNP
Y      | Business     | NEW_ACCOUNT_ACTION            | MNP
Y      | Postpaid     | NEW_ACCOUNT_ACTION            | MNP
N      | Postpaid     | NEW_ACCOUNT_ACTION            | new postpaid
N      | Postpaid     | MIGRATION_ACTION              | Migration
N      | Postpaid     | REREGISTRATION_ACTION         | REREGISTRATION
N      | Postpaid     | AUCTION_ACTION                | NULL
N      | Prepaid      | NEW_ACCOUNT_ACTION            | new prepaid
N      | Prepaid      | REREGISTRATION_ACTION         | REREGISTRATION
N      | Prepaid      | CESSATION_ACTION              | NULL
N      | Fixed        | NEW_ACCOUNT_ACTION            | elife
N      | Fixed        | MANAGE_SERVICE_ACTION         | elife
N      | Business     | NEW_ACCOUNT_ACTION            | NULL
N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL
N      | Business     | REREGISTRATION_ACTION         | REREGISTRATION
N      | BUlitmate    | REREGISTRATION_ACTION         | REREGISTRATION
N      | Hassantuk    | HASSANTUK_ACTION              | NULL
N      | NULL         | NULL                          | NULL
```

## Breakdown by Classification

### 1. MNP Transactions (3 records)
**Rule:** IS_MNP = 'Y'  
**Result:** transactional_type = 'MNP'

```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
Y      | Prepaid      | NEW_ACCOUNT_ACTION | MNP
Y      | Business     | NEW_ACCOUNT_ACTION | MNP
Y      | Postpaid     | NEW_ACCOUNT_ACTION | MNP
```

**Insight:** All MNP-flagged transactions are classified as 'MNP' regardless of product type or action.

---

### 2. New Postpaid Accounts (1 record)
**Rule:** IS_MNP = 'N' AND ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid'  
**Result:** transactional_type = 'new postpaid'

```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
N      | Postpaid     | NEW_ACCOUNT_ACTION | new postpaid
```

**Insight:** Standard postpaid account creation without number portability.

---

### 3. New Prepaid Accounts (1 record)
**Rule:** IS_MNP = 'N' AND ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid'  
**Result:** transactional_type = 'new prepaid'

```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
N      | Prepaid      | NEW_ACCOUNT_ACTION | new prepaid
```

**Insight:** Standard prepaid account creation without number portability.

---

### 4. Migration Transactions (1 record)
**Rule:** ACTON = 'MIGRATION_ACTION'  
**Result:** transactional_type = 'Migration'

```
IS_MNP | PRODUCT_TYPE | ACTON            | transactional_type
-------|--------------|------------------|-----------------
N      | Postpaid     | MIGRATION_ACTION | Migration
```

**Insight:** Customer migrating between plans or services.

---

### 5. Reregistration Transactions (4 records)
**Rule:** ACTON = 'REREGISTRATION_ACTION'  
**Result:** transactional_type = 'REREGISTRATION'

```
IS_MNP | PRODUCT_TYPE | ACTON                 | transactional_type
-------|--------------|------------------------|-----------------
N      | Postpaid     | REREGISTRATION_ACTION | REREGISTRATION
N      | Prepaid      | REREGISTRATION_ACTION | REREGISTRATION
N      | Business     | REREGISTRATION_ACTION | REREGISTRATION
N      | BUlitmate    | REREGISTRATION_ACTION | REREGISTRATION
```

**Insight:** Reregistration applies across all product types.

---

### 6. eLife / Fixed Services (2 records)
**Rule:** PRODUCT_TYPE = 'Fixed'  
**Result:** transactional_type = 'elife'

```
IS_MNP | PRODUCT_TYPE | ACTON                 | transactional_type
-------|--------------|------------------------|-----------------
N      | Fixed        | NEW_ACCOUNT_ACTION     | elife
N      | Fixed        | MANAGE_SERVICE_ACTION  | elife
```

**Insight:** All Fixed product type transactions are classified as 'elife' regardless of action.

---

### 7. Unclassified Transactions (4 records + 1 null)
**Rule:** None of the above rules match  
**Result:** transactional_type = NULL

```
IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type
-------|--------------|-------------------------------|-----------------
N      | Business     | NEW_ACCOUNT_ACTION            | NULL
N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL
N      | Postpaid     | AUCTION_ACTION                | NULL
N      | Prepaid      | CESSATION_ACTION              | NULL
N      | Hassantuk    | HASSANTUK_ACTION              | NULL
N      | NULL         | NULL                          | NULL
```

**Insight:** These transactions don't fit into the defined business rules and require manual classification or new rules.

---

## Summary Statistics

```sql
-- Count by transactional_type
SELECT 
    COALESCE(transactional_type, 'Unclassified') as category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM (
    -- Main query result
) X
GROUP BY transactional_type
ORDER BY count DESC;
```

**Expected Output:**
```
category        | count | percentage
----------------|-------|------------
Unclassified    | 6     | 33.33%
REREGISTRATION  | 4     | 22.22%
MNP             | 3     | 16.67%
elife           | 2     | 11.11%
new postpaid    | 1     | 5.56%
new prepaid     | 1     | 5.56%
Migration       | 1     | 5.56%
----------------|-------|------------
Total           | 18    | 100.00%
```

---

## Business Insights

### Distribution Analysis
1. **33.33%** of transactions are unclassified - May need additional business rules
2. **22.22%** are reregistration activities across all product types
3. **16.67%** are MNP (number portability) transactions
4. **11.11%** are Fixed/elife services
5. **11.11%** are new account activations (postpaid + prepaid, non-MNP)
6. **5.56%** are migration activities

### Recommendations
1. **Define rules for Business NEW_ACCOUNT_ACTION** - Currently returns NULL
2. **Review special actions** - AUCTION_ACTION, CESSATION_ACTION, HASSANTUK_ACTION, TRANSFER_OF_OWNERSHIP_ACTION
3. **Consider adding more granular classifications** for specific use cases
4. **Monitor NULL values** to identify patterns requiring new business rules

---

## Testing the Query

### Option 1: Run Main Query
```bash
# Execute the main query
@TRANSACTIONAL_TYPE_QUERY.sql

# Review output for:
# - All expected classifications present
# - No unexpected NULL values
# - Correct priority ordering (MNP takes precedence)
```

### Option 2: Run Validation Test
```bash
# Execute the validation test
@TRANSACTIONAL_TYPE_TEST.sql

# Expected result:
# tests_passed | total_tests | validation_status
# -------------|-------------|------------------
# 18           | 18          | ALL TESTS PASSED ✓
```

### Option 3: Manual Spot Check
```sql
-- Check MNP classification
SELECT * FROM (...) WHERE IS_MNP = 'Y';
-- Should all show transactional_type = 'MNP'

-- Check new postpaid
SELECT * FROM (...) WHERE PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' AND IS_MNP = 'N';
-- Should show transactional_type = 'new postpaid'

-- Check Fixed/elife
SELECT * FROM (...) WHERE PRODUCT_TYPE = 'Fixed';
-- Should all show transactional_type = 'elife'
```

---

## Next Steps

1. **Validate with Production Data**
   - Run query on actual data from DEV_STG schema
   - Compare results with expected business outcomes
   - Identify any unexpected patterns

2. **Implement in ETL Pipeline**
   - Add transactional_type column to data warehouse tables
   - Update downstream reports and dashboards
   - Create alerts for unusual classification patterns

3. **Monitor and Iterate**
   - Track NULL value percentage over time
   - Gather feedback from business users
   - Add new rules as business requirements evolve

4. **Documentation**
   - Keep TRANSACTIONAL_TYPE_MAPPING.md updated
   - Document any new rules or changes
   - Maintain test cases for regression testing

---

## Troubleshooting

### Issue: All transactions showing NULL
**Cause:** Data type mismatch or case sensitivity  
**Solution:** Check that IS_MNP values are exactly 'Y' or 'N' (uppercase), and ACTON/PRODUCT_TYPE match exactly

### Issue: MNP not taking priority
**Cause:** CASE statement order is incorrect  
**Solution:** Ensure MNP check is first WHEN clause in CASE statement

### Issue: Unexpected classifications
**Cause:** Data contains variations not in test cases  
**Solution:** Review actual data values, add new test cases, adjust rules as needed

### Issue: Performance problems
**Cause:** Large dataset, complex joins  
**Solution:** Add indexes on IS_MNP, PRODUCT_TYPE, ACTON columns; consider materialized views

---

## Support

For questions or issues:
1. Review [TRANSACTIONAL_TYPE_MAPPING.md](TRANSACTIONAL_TYPE_MAPPING.md) for detailed rules
2. Run [TRANSACTIONAL_TYPE_TEST.sql](TRANSACTIONAL_TYPE_TEST.sql) to validate logic
3. Check [README.md](README.md) for usage examples
4. Consult with business stakeholders for rule clarifications
