# Enhanced Query 2 - Business Justification

## Overview
Based on actual variance analysis, the business requires tracking both INBOUND and OUTBOUND perspectives for transfer transactions to maintain proper audit trails and reconciliation capabilities.

---

## Business Requirement

**User Feedback:**
> "The variance I found in reality was in SHOP to SHOP, SHOP to WH and WH to SHOP. We also need to add the inbound and outbound to the 2nd DWH query."

**Translation:**
The original recommendation to eliminate duplication was incorrect for the business use case. Both perspectives (INBOUND and OUTBOUND) are needed for:
1. **Originating location accountability** - Track what was sent out
2. **Receiving location accountability** - Track what was received
3. **Reconciliation** - Compare sent vs received quantities
4. **Audit trail** - Complete transaction visibility from both sides

---

## Changes Made to Query 2

### Original Query 2 Approach
- Single record per transfer
- Example: SHOP TO SHOP recorded once

### Enhanced Query 2 Approach
- Double record per transfer (OUTBOUND + INBOUND)
- Matches Query 1 structure but with Query 2's improvements

---

## Transaction Types with INBOUND/OUTBOUND

### 1. WH TO SHOP

**OUTBOUND (Warehouse Perspective):**
```sql
'WH TO SHOP_OUTBOUND' TRANSACTION_TYPE
-- Records the shipment from warehouse
-- From: Warehouse (ORIGINATING_STORE_ID)
-- To: Shop (RECEIVING_STORE_ID)
```

**INBOUND (Shop Perspective):**
```sql
'WH TO SHOP_INBOUND' TRANSACTION_TYPE
-- Records the receipt at shop
-- From: Warehouse (ORIGINATING_STORE_ID)
-- To: Shop (RECEIVING_STORE_ID)
```

**Business Value:**
- Warehouse tracks shipments sent
- Shop tracks deliveries received
- Enables shipment vs receipt reconciliation
- Identifies lost/damaged goods in transit

---

### 2. SHOP TO WH

**OUTBOUND (Shop Perspective):**
```sql
'SHOP TO WH_OUTBOUND' TRANSACTION_TYPE
-- Records the return from shop
-- From: Shop (ORIGINATING_STORE_ID)
-- To: Warehouse (RECEIVING_STORE_ID)
```

**INBOUND (Warehouse Perspective):**
```sql
'SHOP TO WH_INBOUND' TRANSACTION_TYPE
-- Records the receipt at warehouse
-- From: Shop (ORIGINATING_STORE_ID)
-- To: Warehouse (RECEIVING_STORE_ID)
```

**Business Value:**
- Shop tracks returns sent
- Warehouse tracks returns received
- Enables return shipment reconciliation
- Tracks processing of damaged/excess inventory

---

### 3. SHOP TO SHOP

**OUTBOUND (Originating Shop Perspective):**
```sql
'SHOP TO SHOP_OUTBOUND' TRANSACTION_TYPE
-- Records the transfer out
-- From: Shop A (ORIGINATING_STORE_ID)
-- To: Shop B (RECEIVING_STORE_ID)
```

**INBOUND (Receiving Shop Perspective):**
```sql
'SHOP TO SHOP_INBOUND' TRANSACTION_TYPE
-- Records the transfer in
-- From: Shop A (ORIGINATING_STORE_ID)
-- To: Shop B (RECEIVING_STORE_ID)
```

**Business Value:**
- Source shop tracks inventory sent
- Destination shop tracks inventory received
- Enables inter-store transfer reconciliation
- Critical for store-level inventory accuracy

---

## Key Improvements Over Query 1

While Enhanced Query 2 now records both perspectives like Query 1, it maintains these improvements:

### 1. **Consistent Timestamps**
- Uses `HDR.UPDSTMP` (header timestamp) for all transfer transactions
- Ensures both INBOUND and OUTBOUND use same date
- Prevents records from falling into different periods

**Query 1 Issue:** Uses `CD.UPDSTMP` (detail timestamp) which can differ

### 2. **No Restrictive Filters**
- Includes ALL transfers (no cost update log requirement)
- Includes ALL sales (no COUPONCODE requirement)
- Includes ALL inventory adjustments (no EXPID1 requirement)

**Query 1 Issue:** Excludes valid transactions with overly restrictive filters

### 3. **Correct Quantity Field**
- Uses `DTL.QTY` for SHOP TO WH transactions
- Represents actual transferred quantity

**Query 1 Issue:** Uses `CD.PREVQTY` which may represent pre-transfer quantity

### 4. **Enhanced Traceability**
- Includes SERIAL numbers
- Includes SUB_REQ_ID
- Includes CSSREFERENCE for WH TO SHOP

**Query 1 Issue:** Missing these traceability fields

---

## Comparison: Query 1 vs Enhanced Query 2

| Aspect | Query 1 | Enhanced Query 2 | Winner |
|--------|---------|------------------|--------|
| **INBOUND/OUTBOUND** | ✓ Yes | ✓ Yes | Tie |
| **Timestamp Consistency** | ❌ Mixed (header/detail) | ✓ Header only | Query 2 |
| **Sales Coverage** | ❌ Missing without COUPONCODE | ✓ Complete | Query 2 |
| **Inventory Coverage** | ❌ Missing without EXPID1 | ✓ Complete | Query 2 |
| **WH TO SHOP Coverage** | ❌ Requires cost log | ✓ Complete | Query 2 |
| **SHOP TO WH Quantity** | ❌ Uses PREVQTY | ✓ Uses QTY | Query 2 |
| **Traceability** | ❌ Limited | ✓ Enhanced | Query 2 |
| **Join Syntax** | ❌ Mixed | ✓ Explicit | Query 2 |

---

## Record Count Impact

### Before Enhancement (Original Query 2):
```
SHOP TO SHOP: N records (one per transfer)
SHOP TO WH: M records (one per return)
WH TO SHOP: W records (one per delivery)
Total Transfer Records: N + M + W
```

### After Enhancement (Enhanced Query 2):
```
SHOP TO SHOP_OUTBOUND: N records
SHOP TO SHOP_INBOUND: N records
SHOP TO WH_OUTBOUND: M records
SHOP TO WH_INBOUND: M records
WH TO SHOP_OUTBOUND: W records
WH TO SHOP_INBOUND: W records
Total Transfer Records: 2N + 2M + 2W = 2(N + M + W)
```

**Result:** Transfer transaction count doubles (as intended for business purposes)

---

## Reconciliation Use Cases

### Use Case 1: Verify Inter-Store Transfer Completion
```sql
-- Find transfers where OUTBOUND exists but no matching INBOUND
SELECT 
    O.REFERENCENO,
    O.ORIGINATING_STORE_ID,
    O.RECEIVING_STORE_ID,
    O.DELIVERED_QUANTITY,
    O.TRANSACTION_DATE
FROM (
    SELECT * FROM enhanced_query_2 
    WHERE TRANSACTION_TYPE = 'SHOP TO SHOP_OUTBOUND'
) O
LEFT JOIN (
    SELECT * FROM enhanced_query_2 
    WHERE TRANSACTION_TYPE = 'SHOP TO SHOP_INBOUND'
) I ON O.REFERENCENO = I.REFERENCENO
WHERE I.REFERENCENO IS NULL;

-- Identifies transfers sent but not received
```

### Use Case 2: Identify Quantity Discrepancies
```sql
-- Compare OUTBOUND vs INBOUND quantities
SELECT 
    O.REFERENCENO,
    O.ORIGINATING_STORE_ID,
    O.RECEIVING_STORE_ID,
    O.DELIVERED_QUANTITY as outbound_qty,
    I.DELIVERED_QUANTITY as inbound_qty,
    O.DELIVERED_QUANTITY - I.DELIVERED_QUANTITY as variance
FROM (
    SELECT * FROM enhanced_query_2 
    WHERE TRANSACTION_TYPE = 'WH TO SHOP_OUTBOUND'
) O
INNER JOIN (
    SELECT * FROM enhanced_query_2 
    WHERE TRANSACTION_TYPE = 'WH TO SHOP_INBOUND'
) I ON O.REFERENCENO = I.REFERENCENO
WHERE O.DELIVERED_QUANTITY <> I.DELIVERED_QUANTITY;

-- Identifies shipment vs receipt quantity differences
```

### Use Case 3: Store-Level Inventory Reconciliation
```sql
-- Calculate net inventory change for a store
SELECT 
    ORIGINATING_STORE_ID as store_id,
    SUM(CASE 
        WHEN TRANSACTION_TYPE LIKE '%OUTBOUND' THEN -DELIVERED_QUANTITY
        WHEN TRANSACTION_TYPE LIKE '%INBOUND' THEN DELIVERED_QUANTITY
        ELSE 0
    END) as net_inventory_change
FROM enhanced_query_2
WHERE TRANSACTION_TYPE IN (
    'SHOP TO SHOP_OUTBOUND', 'SHOP TO SHOP_INBOUND',
    'SHOP TO WH_OUTBOUND', 'WH TO SHOP_INBOUND'
)
GROUP BY ORIGINATING_STORE_ID;
```

---

## Implementation Notes

### For Data Warehouse Modeling:

1. **Fact Table Structure:**
   ```
   TRANSACTION_TYPE: varchar(50)  -- Includes _OUTBOUND or _INBOUND suffix
   DIRECTION: varchar(10)          -- Derived: 'OUTBOUND' or 'INBOUND'
   BASE_TYPE: varchar(20)          -- Derived: 'SHOP TO SHOP', 'SHOP TO WH', 'WH TO SHOP'
   ```

2. **Aggregation Considerations:**
   - When counting total transfers: COUNT(*) / 2 for transfer types
   - When summing quantities: Filter to OUTBOUND only to avoid double-counting
   - When analyzing by location: Use both perspectives for complete picture

3. **Reporting:**
   - **Shipment Reports:** Use _OUTBOUND records
   - **Receipt Reports:** Use _INBOUND records
   - **Reconciliation Reports:** Compare both
   - **Inventory Flow:** Use both perspectives

---

## Migration Strategy

### From Query 1 to Enhanced Query 2:

**Step 1:** Validate Data Completeness
```sql
-- Check if Enhanced Query 2 has more complete data
SELECT 
    'Query 1' as source,
    COUNT(*) as total_records
FROM query_1_results
UNION ALL
SELECT 
    'Enhanced Query 2' as source,
    COUNT(*) as total_records
FROM enhanced_query_2_results;
```

**Step 2:** Reconcile Transaction Counts by Type
```sql
-- Compare by transaction type
SELECT 
    TRANSACTION_TYPE,
    COUNT(*) as record_count
FROM query_1_results
GROUP BY TRANSACTION_TYPE
ORDER BY TRANSACTION_TYPE;

-- vs

SELECT 
    TRANSACTION_TYPE,
    COUNT(*) as record_count
FROM enhanced_query_2_results
GROUP BY TRANSACTION_TYPE
ORDER BY TRANSACTION_TYPE;
```

**Step 3:** Switch Data Pipeline
- Update ETL to use Enhanced Query 2
- Maintain Query 1 in parallel for validation period
- Compare results for 1-2 reporting cycles
- Deprecate Query 1 after validation

---

## Summary

**Original Analysis:** Recommended eliminating INBOUND/OUTBOUND duplication

**Revised Understanding:** Business requires both perspectives for proper inventory management

**Solution:** Enhanced Query 2 that:
- ✓ Maintains INBOUND/OUTBOUND for transfer transactions
- ✓ Uses consistent header timestamps
- ✓ Includes all transactions (no restrictive filters)
- ✓ Uses correct quantity fields
- ✓ Provides enhanced traceability
- ✓ Enables reconciliation and audit

**Recommendation:** **Use Enhanced Query 2** for DWH modeling. It provides the dual-perspective tracking the business needs while fixing all the data quality issues in Query 1.

---

## File Reference

**Enhanced Query:** See `ENHANCED_QUERY_2_WITH_INBOUND_OUTBOUND.sql`

**Original Analysis:** See `FINAL_RECOMMENDATIONS.md` (note: recommendation to eliminate duplication was based on assumption of single-perspective tracking)
