# Query Discrepancy Summary

## Executive Summary

**Root Causes of Data Gap:**
1. **SHOP TO SHOP double-counting** - Query 1 records each transfer twice (OUTBOUND + INBOUND)
2. **Missing Sales transactions** - Query 1 filters out records without COUPONCODE
3. **Missing Inventory adjustments** - Query 1 filters out records without EXPID1
4. **Missing WH TO SHOP records** - Query 1 requires cost update log entries
5. **Inconsistent timestamps** - Different date fields cause records to appear in different periods
6. **Wrong quantity field** - Query 1 uses prevqty instead of qty for SHOP TO WH

**Recommendation:** Use Query 2 as the standard. It is more complete and accurate.

---

## Detailed Comparison Table

| Aspect | Query 1 (Reporting Tool) | Query 2 (DWH Source) | Impact |
|--------|-------------------------|---------------------|--------|
| **SHOP TO SHOP** | Two queries: OUTBOUND + INBOUND | Single query | Query 1 has **2x records** |
| **Sales/Return/Cancel** | Requires COUPONCODE IS NOT NULL | No COUPONCODE filter | Query 1 **missing records** |
| **Inventory (INV)** | Requires EXPID1 IS NOT NULL | No EXPID1 filter | Query 1 **missing records** |
| **WH TO SHOP join** | INNER JOIN to cost update log | No cost update log dependency | Query 1 **missing records** |
| **SHOP TO WH quantity** | Uses cd.prevqty | Uses DTL.QTY | **Different totals** |
| **SHOP TO WH date** | Uses cd.UPDSTMP (detail) | Uses HDR.UPDSTMP (header) | **Date range differences** |
| **SHOP TO SHOP date** | Uses cd.UPDSTMP (detail) | Uses HDR.UPDSTMP (header) | **Date range differences** |
| **Join syntax** | Old-style comma joins | Explicit INNER/LEFT JOIN | Query 2 more maintainable |

---

## Transaction Type Mapping

| Transaction Type | Query 1 Name(s) | Query 2 Name | Records Ratio |
|-----------------|----------------|--------------|---------------|
| Warehouse to Shop | WH TO SHOP | WH TO SHOP | 1:1 (if no cost log filter) |
| Shop to Warehouse | SHOP TO WH | SHOP TO WH | 1:1 |
| Shop to Shop | SHOP TO SHOP_OUTBOUND + SHOP TO SHOP_INBOUND | SHOP TO SHOP | **2:1** |
| Sales | SALE | SALE | 1:1 (if no COUPONCODE filter) |
| Returns | RETURN | RETURN | 1:1 (if no COUPONCODE filter) |
| Cancels | CANCEL | CANCEL | 1:1 (if no COUPONCODE filter) |
| Inventory | INV | STOCK TAKE ADJUSTMENTS... | 1:1 (if no EXPID1 filter) |

---

## Field Mapping

### Common Fields (with differences highlighted)

| Logical Field | Query 1 Field | Query 2 Field | Notes |
|--------------|---------------|---------------|-------|
| Product Group | Product_Group | N/A | Not in Query 2 output |
| Store ID | store_pos_id | ORIGINATING_STORE_ID | Same source |
| Store Name | store_name | ORIGINATING_STORE_NAME | Same source |
| Target Store ID | target_store | RECEIVING_STORE_ID | Same source |
| Target Store Name | target_store_name | RECEIVING_STORE_NAME | Same source |
| Item Code | Item_code | SIC | Same source |
| Item Description | Item_description | SIC_DESCRIPTION | Query 1 blank for INV |
| Batch/Serial | Batch_id | REFERENCENO | Different sources |
| Transaction Date | Transaction_date | TRANSACTION_DATE | **Different fields used** |
| Transaction Type | Transaction_type | TRANSACTION_TYPE | **Different naming** |
| UOM | UOM | N/A | Not in Query 2 output |
| Quantity | QTY | DELIVERED_QUANTITY | **Different for SHOP TO WH** |
| Unit Cost | unit_cost | AUC | Same source (M.EMPPRICE) |
| Total | Total | TOTAL_COST | Depends on quantity used |

### Additional Fields in Query 1
- Sub_Inventory (SS.STOCKCPT)
- store_type (O.OFFNAM2)
- ERP_AUC (from cost update log)
- ERP_TOTAL (from cost update log)
- updated_unit_cost (from cost update log)
- WINCASH_FORMULA_TOTAL (from cost update log)

### Additional Fields in Query 2
- SERIAL (SERTXT, SERNOS)
- SUB_REQ_ID (from VOU2FLEXFIELD)
- CSSREFERENCE (from DBOD)

---

## Specific Query Differences

### 1. SALES/RETURN/CANCEL

**Query 1:**
```sql
WHERE VH.VOUTYPE in ('V','R','S')
  AND COUPONCODE IS NOT NULL  -- ← Excludes records without batch
```

**Query 2:**
```sql
WHERE VH.VOUTYPE in ('V','R','S')
  -- No COUPONCODE filter - includes all sales
```

**Impact:** Query 1 excludes sales without a coupon/batch code. This could be a significant number of transactions.

---

### 2. INVENTORY ADJUSTMENTS

**Query 1:**
```sql
-- Filters twice for EXPID1
AND MV.EXPID1 IS NOT NULL
AND EXPID1 IS NOT NULL
-- Simple transaction type
Transaction_type: 'INV'
```

**Query 2:**
```sql
-- No EXPID1 filter
-- Categorizes adjustments by direction
CASE 
    WHEN MV.QTY < 0 THEN 'STOCK TAKE ADJUSTMENTS PHYSICAL SHORTAGE AND SYSTEM EXCESS' 
    WHEN MV.QTY > 0 THEN 'STOCK TAKE ADJUSTMENTS PHYSICAL EXCESS and SYSTEM SHORTAGE' 
END
```

**Impact:** Query 1 excludes inventory adjustments without EXPID1. Query 2 provides better categorization.

---

### 3. WH TO SHOP

**Query 1:**
```sql
-- Inner join requires matching cost update log record
INNER JOIN (...
    FROM WINPROD.etsuae_cost_update_log lg
    GROUP BY ...
) lgg
WHERE od.ordid = lgg.wincash_order and od.matno = lgg.item_code
```

**Query 2:**
```sql
-- No dependency on cost update log
-- Optional join to delivery note
LEFT OUTER JOIN (SELECT distinct REFNO, DELNOTENO FROM WINPROD.DBOD) D
```

**Impact:** Query 1 only shows WH TO SHOP transactions that have been logged in the cost update table. This could exclude recent or unprocessed deliveries.

---

### 4. SHOP TO SHOP

**Query 1:**
```sql
-- FIRST QUERY: OUTBOUND perspective
SELECT ... 'SHOP TO SHOP_OUTBOUND' Transaction_type
FROM WINPROD.cmsdtl cd
    JOIN WINPROD.cmshdr ch ON cd.cmsid = ch.gid
WHERE cd.dtlstatus = 'C'
  AND TRUNC(cd.UPDSTMP) BETWEEN ...  -- Detail timestamp

UNION ALL

-- SECOND QUERY: INBOUND perspective  
SELECT ... 'SHOP TO SHOP_INBOUND' Transaction_type
FROM WINPROD.cmsdtl cd
    JOIN WINPROD.cmshdr ch ON cd.cmsid = ch.gid
WHERE cd.dtlstatus = 'C'
  AND TRUNC(cd.UPDSTMP) BETWEEN ...  -- Detail timestamp
```

**Query 2:**
```sql
-- SINGLE QUERY: One record per transfer
SELECT ... 'SHOP TO SHOP' TRANSACTION_TYPE
FROM WINPROD.CMSHDR HDR
    INNER JOIN WINPROD.CMSDTL DTL ON HDR.GID = DTL.CMSID
WHERE DTL.DTLSTATUS = 'C'
  AND TRUNC(HDR.UPDSTMP) BETWEEN ...  -- Header timestamp
```

**Impact:** Query 1 creates DOUBLE the records. Each transfer appears as both an outbound from source store and inbound to destination store.

---

### 5. SHOP TO WH

**Query 1:**
```sql
SELECT ... cd.prevqty  -- Previous quantity
FROM WINPROD.cmsdtl cd
    JOIN WINPROD.cmshdr ch
WHERE TRUNC(cd.UPDSTMP) BETWEEN ...  -- Detail timestamp
```

**Query 2:**
```sql
SELECT ... DTL.QTY  -- Standard quantity
FROM WINPROD.CMSHDR HDR
    INNER JOIN WINPROD.CMSDTL DTL
WHERE TRUNC(HDR.UPDSTMP) BETWEEN ...  -- Header timestamp
```

**Impact:** 
- Different quantities (prevqty vs QTY) lead to different totals
- Different timestamps may cause records to appear in different periods

---

## Reconciliation Formula

To estimate the gap between queries:

```
Query1_RecordCount ≈ Query2_RecordCount + ShopToShop_Count - Missing_Sales - Missing_INV - Missing_WHTOSHOP

Where:
- ShopToShop_Count = Number of SHOP TO SHOP records (Query 1 has 2x these)
- Missing_Sales = Sales without COUPONCODE
- Missing_INV = Inventory adjustments without EXPID1  
- Missing_WHTOSHOP = WH TO SHOP records without cost update log entry
```

If Query 1 has MORE records than Query 2:
→ The SHOP TO SHOP double-counting exceeds the missing records

If Query 1 has FEWER records than Query 2:
→ The missing records (Sales, INV, WHTOSHOP) exceed the SHOP TO SHOP double-counting

---

## Recommended Actions

### Immediate Actions:
1. ✅ **Use Query 2 as the authoritative source** for DWH modeling
2. ✅ **Deprecate Query 1** or update it to match Query 2 logic
3. ⚠️ **Investigate SHOP TO SHOP double-counting** in existing reports
4. ⚠️ **Review historical data** to understand impact of missing records

### Query 1 Corrections (if must be retained):
1. **Remove SHOP TO SHOP_INBOUND** query to eliminate duplication
2. **Remove COUPONCODE IS NOT NULL** filter
3. **Remove EXPID1 IS NOT NULL** filter  
4. **Change SHOP TO WH** to use `cd.qty` instead of `cd.prevqty`
5. **Change date filters** to use header timestamps (ch.UPDSTMP, oh.UPDSTMP)
6. **Change WH TO SHOP** join to LEFT OUTER JOIN for cost update log

### Validation Queries:

```sql
-- Count records by transaction type in Query 1
SELECT Transaction_type, COUNT(*) as record_count
FROM (Query 1)
GROUP BY Transaction_type;

-- Count records by transaction type in Query 2  
SELECT TRANSACTION_TYPE, COUNT(*) as record_count
FROM (Query 2)
GROUP BY TRANSACTION_TYPE;

-- Find sales without COUPONCODE (missing from Query 1)
SELECT COUNT(*)
FROM WINPROD.VOUHDR VH
    INNER JOIN WINPROD.VOUDTL VD ON VH.JOUID = VD.JOUID
WHERE VH.VOUTYPE in ('V','R','S')
  AND COUPONCODE IS NULL
  AND TRUNC(VH.POSDAT) BETWEEN ... AND ...;

-- Find inventory adjustments without EXPID1 (missing from Query 1)
SELECT COUNT(*)
FROM WINPROD.MATMOVE MV
WHERE MV.MVTYPEID IN (SELECT GID FROM WINPROD.MATMOVETYPE WHERE MMTCODE = 'INV')
  AND MV.QTY <> 0
  AND MV.EXPID1 IS NULL
  AND TRUNC(MV.UPDSTMP) BETWEEN ... AND ...;
```

---

## Conclusion

**Query 2 is significantly more accurate** because it:
- ✅ Avoids double-counting
- ✅ Includes all transactions (no arbitrary filters)
- ✅ Uses consistent timestamp logic
- ✅ Has cleaner join structure
- ✅ Provides additional traceability fields

**Query 1 should be corrected** or replaced to avoid:
- ❌ Inflated SHOP TO SHOP counts
- ❌ Missing sales, returns, and cancels
- ❌ Missing inventory adjustments
- ❌ Missing WH TO SHOP deliveries
- ❌ Incorrect SHOP TO WH quantities
- ❌ Date range inconsistencies
