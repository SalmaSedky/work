# SQL Query Comparison Analysis

## Overview
This document compares two SQL queries designed to extract transaction data from the WINPROD system:
- **Query 1**: Current reporting tool query
- **Query 2**: Source query for DWH modeling

Both queries should theoretically return the same data, but there are significant differences that explain the gaps in results.

---

## Key Differences Summary

### 1. **SHOP TO SHOP Transaction Handling**

#### Query 1 (Reporting Tool):
- Splits SHOP TO SHOP into **two separate queries**:
  - `SHOP TO SHOP_OUTBOUND` - from originating store perspective
  - `SHOP TO SHOP_INBOUND` - from receiving store perspective
- Both queries join: `WINPROD.cmsdtl cd` → `WINPROD.cmshdr ch`
- Uses `cd.UPDSTMP` as transaction date
- Filter: `cd.dtlstatus = 'C'`

#### Query 2 (DWH Source):
- Has **single query** `SHOP TO SHOP`
- Joins: `WINPROD.CMSHDR HDR` → `WINPROD.CMSDTL DTL`
- Uses `HDR.UPDSTMP` as transaction date
- Filter: `DTL.DTLSTATUS = 'C'`

**Impact**: Query 1 will have **DOUBLE the records** for SHOP TO SHOP transfers because it records both the outbound and inbound sides of the same transfer.

---

### 2. **Transaction Date Field Differences**

#### SHOP TO WH:
- **Query 1**: Uses `cd.UPDSTMP` (detail-level timestamp)
- **Query 2**: Uses `HDR.UPDSTMP` (header-level timestamp)

#### SHOP TO SHOP:
- **Query 1**: Uses `cd.UPDSTMP` (detail-level timestamp) for both OUTBOUND and INBOUND
- **Query 2**: Uses `HDR.UPDSTMP` (header-level timestamp)

**Impact**: Transactions may fall into different date ranges if the header and detail timestamps differ.

---

### 3. **WH TO SHOP Transactions**

#### Query 1:
```sql
-- Joins with cost update log table
from WINPROD.orddtl od, ... (
    select lg.wincash_order,lg.css_order,lg.item_code,lg.unit_cost,
           max(lg.updated_unit_cost) updated_unit_cost,
           sum(lg.trans_qty) trans_qty
    from WINPROD.etsuae_cost_update_log lg 
    group by lg.wincash_order,lg.css_order,lg.item_code,lg.unit_cost
) lgg
WHERE od.ordid = lgg.wincash_order and od.matno = lgg.item_code
```
- **Requires** a matching record in `etsuae_cost_update_log`
- Returns additional columns: `ERP_AUC`, `ERP_TOTAL`, `updated_unit_cost`, `WINCASH_FORMULA_TOTAL`

#### Query 2:
```sql
FROM WINPROD.ORDHDR OH
INNER JOIN WINPROD.ORDDTL OD ON OH.ORDiD = OD.ORDID
LEFT OUTER JOIN (SELECT distinct REFNO, DELNOTENO FROM WINPROD.DBOD) D 
    ON D.REFNO = OH.OrdID
```
- **Does NOT require** `etsuae_cost_update_log` match
- Includes optional join to `DBOD` for CSS reference

**Impact**: Query 1 will have **FEWER records** as it only includes WH TO SHOP transactions that have been logged in the cost update table.

---

### 4. **SHOP TO WH Quantity Field**

#### Query 1:
```sql
cd.prevqty  -- Previous quantity field
```

#### Query 2:
```sql
DTL.QTY     -- Standard quantity field
```

**Impact**: Different quantity values may result in different totals if `prevqty` and `QTY` contain different values.

---

### 5. **Sales/Return/Cancel Filtering**

#### Query 1:
```sql
WHERE VH.VOUTYPE in ('V','R','S')
  AND COUPONCODE IS NOT NULL  -- ← Additional filter
```

#### Query 2:
```sql
WHERE VH.VOUTYPE in ('V','R','S')
  -- No COUPONCODE filter
```

**Impact**: Query 1 will have **FEWER records** as it excludes sales/returns/cancels without a coupon code (batch ID).

---

### 6. **Inventory/Stock Take Filtering**

#### Query 1:
```sql
WHERE MV.QTY <> 0 
  AND mv.EXPID1 IS NOT NULL  -- ← Additional filter
AND EXPID1 IS NOT NULL       -- ← Redundant filter
```

#### Query 2:
```sql
WHERE MV.QTY <> 0
  -- No EXPID1 filter
  -- Uses CASE to categorize as shortage vs excess
```

**Impact**: Query 1 will have **FEWER records** as it only includes inventory adjustments with an EXPID1 value.

---

### 7. **Additional Fields in Query 2**

Query 2 includes fields not present in Query 1:
- `SERIAL` (SERTXT for sales, SERNOS for stock take)
- `SUB_REQ_ID` (from VOU2FLEXFIELD table)
- Standardized `REFERENCENO` field
- `CSSREFERENCE` (from DBOD table for WH TO SHOP)

---

## Root Cause Analysis

### Why There's a Gap Between the Queries:

1. **Double-counting in Query 1**: SHOP TO SHOP transactions appear twice (OUTBOUND + INBOUND)
2. **Missing transactions in Query 1**: 
   - WH TO SHOP without cost update log entries
   - Sales/Returns/Cancels without COUPONCODE
   - Inventory adjustments without EXPID1
3. **Date range mismatches**: Using detail vs header timestamps may cause records to fall outside date filters
4. **Quantity differences**: Using `prevqty` vs `QTY` for SHOP TO WH

---

## Recommendations

### Which Query is More Correct?

**Query 2 (DWH Source)** appears to be more accurate for the following reasons:

#### ✅ Advantages of Query 2:
1. **No double-counting**: SHOP TO SHOP is recorded once per transfer
2. **More complete data**: Doesn't exclude transactions based on optional fields (COUPONCODE, EXPID1)
3. **Better data model**: Uses header timestamps consistently for multi-line transactions
4. **Additional context**: Includes SERIAL, SUB_REQ_ID, and references for traceability
5. **Proper join structure**: Uses explicit INNER/LEFT OUTER JOIN syntax (more readable and maintainable)

#### ❌ Issues with Query 1:
1. **Double-counting**: SHOP TO SHOP appears as both OUTBOUND and INBOUND
2. **Incomplete data**: Excludes valid transactions without COUPONCODE or EXPID1
3. **Inconsistent dating**: Mixes header and detail timestamps
4. **Complex dependencies**: Requires `etsuae_cost_update_log` which may not contain all records
5. **Less maintainable**: Uses old-style comma joins mixed with INNER JOIN

---

## Suggested Corrections for Query 1

### Critical Fixes:

1. **Remove SHOP TO SHOP duplication**:
   - Keep only `SHOP TO SHOP_OUTBOUND` OR create a single unified query
   - Alternatively, add a flag to distinguish outbound vs inbound if both perspectives are needed

2. **Remove overly restrictive filters**:
   ```sql
   -- Remove: AND COUPONCODE IS NOT NULL
   -- Remove: AND EXPID1 IS NOT NULL
   ```

3. **Use consistent date fields**:
   - For SHOP TO WH and SHOP TO SHOP: Use `ch.UPDSTMP` (header) instead of `cd.UPDSTMP` (detail)

4. **Fix WH TO SHOP join**:
   - Change INNER JOIN with cost update log to LEFT OUTER JOIN
   - OR add separate query for records not in cost update log

5. **Fix SHOP TO WH quantity**:
   - Verify if `prevqty` is correct or should be `qty`
   - Use `DTL.QTY` for consistency with other transaction types

### Example Corrected SHOP TO SHOP Section:
```sql
-- Single SHOP TO SHOP query (replaces both OUTBOUND and INBOUND)
SELECT mt.mgnam Product_Group, o.offno store_pos_id, o.offnam store_name,
       to_char(o1.offno) target_store, o1.offnam target_store_name,
       ss.stockcpt Sub_Inventory, o.offnam2 store_type,
       m.matno Item_code, m.matnam Item_description, '0' Batch_id,
       ch.UPDSTMP Transaction_date,  -- Use header timestamp
       'SHOP TO SHOP' Transaction_type, MU.Unitnam UOM,
       cd.qty QTY, M.Empprice unit_cost, cd.qty * M.Empprice Total,
       '' ERP_AUC, '' ERP_TOTAL, '' updated_unit_cost, '' WINCASH_FORMULA_TOTAL
FROM WINPROD.cmshdr ch
    INNER JOIN WINPROD.cmsdtl cd ON ch.gid = cd.cmsid
    INNER JOIN WINPROD.material m ON cd.matno = m.matno AND m.TREEID IN (0,1)
    INNER JOIN WINPROD.office o ON cd.treeid = o.treeid
    INNER JOIN WINPROD.office o1 ON cd.dsttreeid = o1.treeid
    INNER JOIN WINPROD.matgroup mt ON m.mgid = mt.gid
    INNER JOIN WINPROD.MATUNIT MU ON m.unitid = mu.gid
    INNER JOIN WINPROD.stock ss ON cd.stockid = ss.gid
WHERE o.status = 'A' 
    AND m.status = 'A' 
    AND o1.status = 'A'
    AND cd.dtlstatus = 'C'
    AND TRUNC(ch.UPDSTMP) BETWEEN TO_DATE(...) AND TO_DATE(...)
```

---

## Reconciliation Checklist

To reconcile the queries, verify:

- [ ] Count of SHOP TO SHOP records in Query 1 is ~2x Query 2
- [ ] Query 1 missing sales records without COUPONCODE
- [ ] Query 1 missing inventory adjustments without EXPID1  
- [ ] WH TO SHOP count differences due to cost update log requirement
- [ ] Date range differences due to header vs detail timestamps
- [ ] Total amounts differ due to `prevqty` vs `QTY` usage

---

## Conclusion

**Query 2 is the more accurate and complete query** for DWH modeling. Query 1 has several issues that cause it to:
- Double-count SHOP TO SHOP transactions
- Exclude valid transactions
- Use inconsistent date fields
- Have unnecessary dependencies on auxiliary tables

For reporting purposes, Query 1 should be modified to align with Query 2's structure and filtering logic.
