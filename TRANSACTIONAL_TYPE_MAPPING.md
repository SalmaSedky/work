# Transactional Type Mapping Documentation

## Overview
This document describes the business logic for classifying transactions into different `transactional_type` categories based on MNP flag, product type, and action type.

---

## Business Rules

### Priority Order
The rules are evaluated in the following priority order (first match wins):

1. **MNP Flag** (Highest Priority)
2. **New Account Actions** (by Product Type)
3. **Migration Actions**
4. **Reregistration Actions**
5. **Fixed Product Type**
6. **Default** (NULL for unmatched cases)

---

## Rule Details

### Rule 1: MNP (Mobile Number Portability)
**Condition:** `IS_MNP = 'Y'`  
**Result:** `transactional_type = 'MNP'`

**Description:**
- Takes highest priority regardless of action or product type
- Identifies transactions where customer is porting their number from another provider
- Applies to all product types when MNP flag is set

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
Y      | Prepaid      | NEW_ACCOUNT_ACTION | MNP
Y      | Business     | NEW_ACCOUNT_ACTION | MNP
Y      | Postpaid     | NEW_ACCOUNT_ACTION | MNP
```

---

### Rule 2: New Postpaid Account
**Condition:** `ACTON = 'NEW_ACCOUNT_ACTION'` AND `PRODUCT_TYPE = 'Postpaid'`  
**Result:** `transactional_type = 'new postpaid'`

**Description:**
- New postpaid subscription activation
- Only applies when MNP flag is 'N' or NULL
- Represents standard postpaid account creation

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
N      | Postpaid     | NEW_ACCOUNT_ACTION | new postpaid
```

---

### Rule 3: New Prepaid Account
**Condition:** `ACTON = 'NEW_ACCOUNT_ACTION'` AND `PRODUCT_TYPE = 'Prepaid'`  
**Result:** `transactional_type = 'new prepaid'`

**Description:**
- New prepaid subscription activation
- Only applies when MNP flag is 'N' or NULL
- Represents standard prepaid account creation

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
N      | Prepaid      | NEW_ACCOUNT_ACTION | new prepaid
```

---

### Rule 4: Migration
**Condition:** `ACTON = 'MIGRATION_ACTION'`  
**Result:** `transactional_type = 'Migration'`

**Description:**
- Customer migrating between plans or services
- Applies to any product type
- Examples: Prepaid to Postpaid migration, plan upgrades/downgrades

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON              | transactional_type
-------|--------------|--------------------|-----------------
N      | Postpaid     | MIGRATION_ACTION   | Migration
```

---

### Rule 5: Reregistration
**Condition:** `ACTON = 'REREGISTRATION_ACTION'`  
**Result:** `transactional_type = 'REREGISTRATION'`

**Description:**
- Re-registration of existing customer or SIM
- Applies to any product type
- May include SIM swap, document updates, etc.

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON                     | transactional_type
-------|--------------|---------------------------|-----------------
N      | Prepaid      | REREGISTRATION_ACTION     | REREGISTRATION
N      | Postpaid     | REREGISTRATION_ACTION     | REREGISTRATION
N      | Business     | REREGISTRATION_ACTION     | REREGISTRATION
N      | BUlitmate    | REREGISTRATION_ACTION     | REREGISTRATION
```

---

### Rule 6: eLife (Fixed Services)
**Condition:** `PRODUCT_TYPE = 'Fixed'`  
**Result:** `transactional_type = 'elife'`

**Description:**
- Fixed broadband/internet services
- Applies regardless of action type
- Represents eLife product line

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON                 | transactional_type
-------|--------------|------------------------|-----------------
N      | Fixed        | MANAGE_SERVICE_ACTION  | elife
N      | Fixed        | NEW_ACCOUNT_ACTION     | elife
```

---

### Rule 7: Default (Unmatched Cases)
**Condition:** None of the above rules match  
**Result:** `transactional_type = NULL`

**Description:**
- Applies to actions/product types not covered by specific rules
- Examples: Business NEW_ACCOUNT_ACTION, special actions, etc.

**Examples:**
```
IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type
-------|--------------|-------------------------------|-----------------
N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL
N      | Business     | NEW_ACCOUNT_ACTION            | NULL
N      | Postpaid     | AUCTION_ACTION                | NULL
N      | Hassantuk    | HASSANTUK_ACTION              | NULL
N      | Prepaid      | CESSATION_ACTION              | NULL
```

---

## Complete Mapping Table

Based on the provided sample data:

| IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type | Notes |
|--------|--------------|-------------------------------|--------------------|-------|
| N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL               | Not covered by rules |
| N      | Business     | NEW_ACCOUNT_ACTION            | NULL               | Business type not handled |
| N      | Postpaid     | AUCTION_ACTION                | NULL               | Action not covered |
| N      | Fixed        | MANAGE_SERVICE_ACTION         | elife              | Fixed = elife |
| N      | Postpaid     | NEW_ACCOUNT_ACTION            | new postpaid       | Rule 2 |
| N      | Postpaid     | MIGRATION_ACTION              | Migration          | Rule 4 |
| N      | Hassantuk    | HASSANTUK_ACTION              | NULL               | Not covered |
| N      | NULL         | NULL                          | NULL               | Blank row |
| N      | Prepaid      | CESSATION_ACTION              | NULL               | Action not covered |
| Y      | Prepaid      | NEW_ACCOUNT_ACTION            | MNP                | Rule 1 (highest priority) |
| N      | Prepaid      | REREGISTRATION_ACTION         | REREGISTRATION     | Rule 5 |
| Y      | Business     | NEW_ACCOUNT_ACTION            | MNP                | Rule 1 (highest priority) |
| Y      | Postpaid     | NEW_ACCOUNT_ACTION            | MNP                | Rule 1 (highest priority) |
| N      | Postpaid     | REREGISTRATION_ACTION         | REREGISTRATION     | Rule 5 |
| N      | Business     | REREGISTRATION_ACTION         | REREGISTRATION     | Rule 5 |
| N      | BUlitmate    | REREGISTRATION_ACTION         | REREGISTRATION     | Rule 5 |
| N      | Fixed        | NEW_ACCOUNT_ACTION            | elife              | Rule 6 |
| N      | Prepaid      | NEW_ACCOUNT_ACTION            | new prepaid        | Rule 3 |

---

## SQL Implementation

### CASE Statement Structure

```sql
CASE
    -- Rule 1: MNP Flag (Highest Priority)
    WHEN IS_MNP = 'Y' THEN 'MNP'
    
    -- Rule 2: New Postpaid Account
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'new postpaid'
    
    -- Rule 3: New Prepaid Account
    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'new prepaid'
    
    -- Rule 4: Migration Action
    WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
    
    -- Rule 5: Reregistration Action
    WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
    
    -- Rule 6: Fixed Product Type (elife)
    WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
    
    -- Default: NULL for unmatched cases
    ELSE NULL
END AS transactional_type
```

---

## Data Sources

### Tables Used
1. **DEV_STG..STG_ORDER_REQUEST_VIEW**
   - Contains: order_id, is_mnp (MNP flag)
   - Filters: CHANNEL_ID = 3, request_status = 'DONE'
   - Date Range: CREATED_DATE_STAMP between 2025-01-01 and 2025-12-31

2. **DEV_STG..STG_REQUEST_BASKET_VW**
   - Contains: order_id, basket_id, product_type, ACTON
   - Date Range: CREATED_DATE_STAMP between 2025-01-01 and 2025-12-31

### Join Logic
- LEFT JOIN on order_id
- Ensures all orders are included even without basket data

---

## Usage Examples

### Query 1: Get All Records with Transactional Type
```sql
SELECT 
    IS_MNP,
    PRODUCT_TYPE,
    ACTON,
    transactional_type
FROM (
    -- Main query logic here
) X
ORDER BY IS_MNP, PRODUCT_TYPE, ACTON;
```

### Query 2: Count by Transactional Type
```sql
SELECT 
    transactional_type,
    COUNT(*) as transaction_count
FROM (
    -- Main query with CASE logic
) X
GROUP BY transactional_type
ORDER BY transaction_count DESC;
```

### Query 3: Filter Specific Types
```sql
SELECT *
FROM (
    -- Main query with CASE logic
) X
WHERE transactional_type IN ('MNP', 'new postpaid', 'new prepaid')
ORDER BY transactional_type;
```

---

## Business Context

### Product Types
- **Postpaid**: Monthly billed mobile services
- **Prepaid**: Pay-as-you-go mobile services
- **Business**: Corporate/business accounts
- **Fixed**: Broadband/internet services (eLife)
- **BUlitmate**: Special product line
- **Hassantuk**: Special service offering

### Action Types
- **NEW_ACCOUNT_ACTION**: New subscription creation
- **MIGRATION_ACTION**: Plan/service migration
- **REREGISTRATION_ACTION**: Customer/SIM re-registration
- **TRANSFER_OF_OWNERSHIP_ACTION**: Account ownership transfer
- **AUCTION_ACTION**: Auction-related action
- **HASSANTUK_ACTION**: Hassantuk service action
- **CESSATION_ACTION**: Service termination
- **MANAGE_SERVICE_ACTION**: Service management

### MNP (Mobile Number Portability)
- Allows customers to switch providers while keeping their number
- Identified by IS_MNP = 'Y'
- Takes priority over all other classifications

---

## Validation and Testing

### Test Cases

1. **MNP Flag Test**
   - Input: IS_MNP = 'Y', any ACTON, any PRODUCT_TYPE
   - Expected: transactional_type = 'MNP'

2. **New Postpaid Test**
   - Input: IS_MNP = 'N', ACTON = 'NEW_ACCOUNT_ACTION', PRODUCT_TYPE = 'Postpaid'
   - Expected: transactional_type = 'new postpaid'

3. **New Prepaid Test**
   - Input: IS_MNP = 'N', ACTON = 'NEW_ACCOUNT_ACTION', PRODUCT_TYPE = 'Prepaid'
   - Expected: transactional_type = 'new prepaid'

4. **Migration Test**
   - Input: IS_MNP = 'N', ACTON = 'MIGRATION_ACTION', any PRODUCT_TYPE
   - Expected: transactional_type = 'Migration'

5. **Reregistration Test**
   - Input: IS_MNP = 'N', ACTON = 'REREGISTRATION_ACTION', any PRODUCT_TYPE
   - Expected: transactional_type = 'REREGISTRATION'

6. **Fixed/eLife Test**
   - Input: IS_MNP = 'N', any ACTON, PRODUCT_TYPE = 'Fixed'
   - Expected: transactional_type = 'elife'

7. **Business Account Test**
   - Input: IS_MNP = 'N', ACTON = 'NEW_ACCOUNT_ACTION', PRODUCT_TYPE = 'Business'
   - Expected: transactional_type = NULL

---

## Maintenance Notes

### Adding New Rules
To add new transactional types:
1. Identify the business condition
2. Determine priority in the CASE statement
3. Add WHEN clause at appropriate position
4. Update this documentation
5. Add test cases

### Modifying Existing Rules
When changing rules:
1. Document the reason for change
2. Update the CASE statement
3. Update this documentation
4. Verify impact on existing data
5. Communicate changes to stakeholders

---

## Change Log

| Date       | Version | Change Description |
|------------|---------|-------------------|
| 2026-02-03 | 1.0     | Initial implementation of transactional_type logic |

---

## References

- Source Query File: `TRANSACTIONAL_TYPE_QUERY.sql`
- Related Documentation: `README.md`
