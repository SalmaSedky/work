# Transaction Variance Prediction

## Overview
This document predicts which specific transactions will show variances between Query 1 (Reporting Tool) and Query 2 (DWH Source), based on the identified issues.

---

## Variance Categories

### 1. SHOP TO SHOP Transactions - **WILL APPEAR DOUBLED IN QUERY 1**

**Prediction:** ALL SHOP TO SHOP transfers will show **2x count** in Query 1

**Identification Criteria:**
```sql
-- These transactions will be DUPLICATED in Query 1:
SELECT DISTINCT 
    CH.GID as transfer_id,
    O.OFFNO as source_store,
    O.OFFNAM as source_store_name,
    O1.OFFNO as destination_store,
    O1.OFFNAM as destination_store_name,
    M.MATNO as item_code,
    CD.QTY as quantity,
    CH.UPDSTMP as transfer_date
FROM WINPROD.CMSHDR CH
    INNER JOIN WINPROD.CMSDTL CD ON CH.GID = CD.CMSID
    INNER JOIN WINPROD.MATERIAL M ON CD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON CD.TREEID = O.TREEID
    INNER JOIN WINPROD.OFFICE O1 ON CD.DSTTREEID = O1.TREEID
WHERE CD.DTLSTATUS = 'C'
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND O1.STATUS = 'A'
    AND TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE];

-- Impact:
-- Query 1: Each record appears TWICE (once as OUTBOUND, once as INBOUND)
-- Query 2: Each record appears ONCE
-- Variance: Query 1 count = 2 × Query 2 count
```

**Example Scenario:**
- Store 101 transfers 50 units of item ABC123 to Store 205 on 2025-11-15
- **Query 1 shows:** 2 records (100 total units)
  - Record 1: SHOP TO SHOP_OUTBOUND, Store 101 → Store 205, 50 units
  - Record 2: SHOP TO SHOP_INBOUND, Store 101 → Store 205, 50 units
- **Query 2 shows:** 1 record (50 total units)
  - Record 1: SHOP TO SHOP, Store 101 → Store 205, 50 units
- **Variance:** +1 record, +50 units in Query 1

---

### 2. Sales/Returns/Cancels WITHOUT COUPONCODE - **MISSING IN QUERY 1**

**Prediction:** Transactions without a batch/coupon code will be **EXCLUDED from Query 1**

**Identification Criteria:**
```sql
-- These transactions will be MISSING from Query 1:
SELECT 
    VH.JOUID,
    O.OFFNO as store_id,
    O.OFFNAM as store_name,
    M.MATNO as item_code,
    M.MATNAM as item_description,
    CASE
        WHEN VD.VOUTYPE = 'V' THEN 'SALE'
        WHEN VD.VOUTYPE = 'R' THEN 'RETURN'
        WHEN VD.VOUTYPE = 'S' THEN 'CANCEL'
    END as transaction_type,
    VD.AM as quantity,
    NVL(VD.EMPPRICE, M.EMPPRICE) as unit_cost,
    ROUND(VD.AM * NVL(VD.EMPPRICE, M.EMPPRICE), 2) as total,
    TRUNC(VH.POSDAT) as transaction_date,
    VD.COUPONCODE as batch_id
FROM WINPROD.VOUHDR VH
    INNER JOIN WINPROD.VOUDTL VD ON VH.JOUID = VD.JOUID AND VH.TREEID = VD.TREEID
    INNER JOIN WINPROD.OFFICE O ON O.TREEID = VD.TREEID
    INNER JOIN WINPROD.MATERIAL M ON M.GID = VD.MATID AND M.STOCKCTRL = 'Y'
WHERE VH.VOUTYPE IN ('V', 'R', 'S')
    AND VD.COUPONCODE IS NULL  -- ← This causes EXCLUSION from Query 1
    AND TRUNC(VH.POSDAT) BETWEEN [START_DATE] AND [END_DATE];

-- Impact:
-- Query 1: EXCLUDES all records where COUPONCODE IS NULL
-- Query 2: INCLUDES all records
-- Variance: Query 2 count > Query 1 count
```

**Transaction Patterns That Will Be Missing:**

1. **Walk-in customer purchases** without promotions
   - Regular sales where no coupon/batch tracking is needed
   - Typical in retail stores for non-promoted items

2. **Manual/emergency transactions** without proper batch assignment
   - Sales processed during system issues
   - Quick sales where batch code entry was skipped

3. **Legacy data** from before COUPONCODE was mandatory
   - Historical transactions imported without batch codes

4. **Returns without original receipt batch**
   - Customer returns where original batch code is unknown

**Example Scenario:**
- Store 101 sells 10 units of item XYZ789 on 2025-11-10 (no promotion/coupon)
- COUPONCODE field is NULL
- **Query 1:** Missing (0 records)
- **Query 2:** Present (1 record)
- **Variance:** -1 record in Query 1

---

### 3. Inventory Adjustments WITHOUT EXPID1 - **MISSING IN QUERY 1**

**Prediction:** Stock take adjustments without EXPID1 will be **EXCLUDED from Query 1**

**Identification Criteria:**
```sql
-- These transactions will be MISSING from Query 1:
SELECT 
    MV.GID as movement_id,
    O.OFFNO as store_id,
    O.OFFNAM as store_name,
    M.MATNO as item_code,
    M.MATNAM as item_description,
    MV.QTY as quantity,
    M.EMPPRICE as unit_cost,
    ROUND(MV.QTY * M.EMPPRICE, 2) as total,
    MV.UPDSTMP as transaction_date,
    MV.EXPID1 as batch_id,
    CASE 
        WHEN MV.QTY < 0 THEN 'PHYSICAL SHORTAGE'
        WHEN MV.QTY > 0 THEN 'PHYSICAL EXCESS'
    END as adjustment_type
FROM WINPROD.MATMOVE MV
    INNER JOIN WINPROD.MATMOVETYPE MVT ON MV.MVTYPEID = MVT.GID
    INNER JOIN WINPROD.MATERIAL M ON MV.MATID = M.GID AND M.STOCKCTRL = 'Y'
    INNER JOIN WINPROD.OFFICE O ON MV.TREEID = O.TREEID
WHERE MVT.MMTCODE = 'INV'
    AND MV.STATUS = 'O'
    AND MV.MVNO2 IS NOT NULL
    AND MV.QTY <> 0
    AND ROUND(MV.QTY * M.EMPPRICE, 2) <> 0
    AND MV.EXPID1 IS NULL  -- ← This causes EXCLUSION from Query 1
    AND TRUNC(MV.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE];

-- Impact:
-- Query 1: EXCLUDES all records where EXPID1 IS NULL
-- Query 2: INCLUDES all records
-- Variance: Query 2 count > Query 1 count
```

**Transaction Patterns That Will Be Missing:**

1. **System-generated adjustments**
   - Automated inventory corrections without batch tracking
   - System reconciliation adjustments

2. **Bulk adjustments across multiple batches**
   - Store-level adjustments that don't specify individual batch
   - Aggregate corrections

3. **Non-batch-tracked items**
   - Items where batch tracking is not required
   - Low-value or non-serialized inventory

4. **Legacy stock take records**
   - Historical adjustments before EXPID1 was implemented

**Example Scenario:**
- Store 302 performs stock take on 2025-11-20
- Discovers shortage of 15 units of item ABC456
- EXPID1 field is NULL (no specific batch identified)
- **Query 1:** Missing (0 records)
- **Query 2:** Present (1 record, -15 units)
- **Variance:** -1 record, -15 units in Query 1

---

### 4. WH TO SHOP Deliveries WITHOUT Cost Update Log Entry - **MISSING IN QUERY 1**

**Prediction:** Deliveries not yet in cost update log will be **EXCLUDED from Query 1**

**Identification Criteria:**
```sql
-- These transactions will be MISSING from Query 1:
SELECT 
    OH.ORDID as order_id,
    S.SUPNO as warehouse_id,
    O.OFFNO as store_id,
    O.OFFNAM as store_name,
    M.MATNO as item_code,
    M.MATNAM as item_description,
    OD.DELQTY as delivered_qty,
    M.EMPPRICE as unit_cost,
    OD.DELQTY * M.EMPPRICE as total,
    OD.UPDSTMP as delivery_date,
    (SELECT COUNT(*) 
     FROM WINPROD.ETSUAE_COST_UPDATE_LOG LG
     WHERE LG.WINCASH_ORDER = OD.ORDID 
       AND LG.ITEM_CODE = OD.MATNO) as in_cost_log
FROM WINPROD.ORDHDR OH
    INNER JOIN WINPROD.ORDDTL OD ON OH.ORDID = OD.ORDID
    INNER JOIN WINPROD.MATERIAL M ON OD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON OD.TREEID = O.TREEID
    INNER JOIN WINPROD.SUPPLIER S ON OD.SUPID = S.GID
WHERE OD.ORDSTATUS = 'C'
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND TRUNC(OD.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE]
    AND NOT EXISTS (
        -- ← These deliveries are EXCLUDED from Query 1
        SELECT 1 
        FROM WINPROD.ETSUAE_COST_UPDATE_LOG LG
        WHERE LG.WINCASH_ORDER = OD.ORDID 
          AND LG.ITEM_CODE = OD.MATNO
    );

-- Impact:
-- Query 1: Only includes deliveries with cost update log entry
-- Query 2: Includes ALL completed deliveries
-- Variance: Query 2 count > Query 1 count
```

**Transaction Patterns That Will Be Missing:**

1. **Recent deliveries** not yet processed
   - Deliveries completed after cost update log batch run
   - Deliveries within current processing cycle

2. **Failed cost processing**
   - Deliveries that failed cost update validation
   - Deliveries with data issues preventing log entry

3. **Manual deliveries** without cost update
   - Emergency deliveries processed outside normal flow
   - Direct store deliveries not routed through cost system

4. **Historical data gaps**
   - Old deliveries before cost update log was implemented
   - Migrated data without log entries

**Example Scenario:**
- Warehouse delivers 100 units of item DEF789 to Store 450 on 2025-11-25
- Delivery is complete (ORDSTATUS = 'C')
- Cost update log batch hasn't run yet
- **Query 1:** Missing (0 records)
- **Query 2:** Present (1 record, 100 units)
- **Variance:** -1 record, -100 units in Query 1

---

### 5. SHOP TO WH with Quantity Variance - **DIFFERENT TOTALS**

**Prediction:** Transactions where `prevqty ≠ qty` will show **different amounts**

**Identification Criteria:**
```sql
-- These transactions will show DIFFERENT AMOUNTS:
SELECT 
    CH.GID as transfer_id,
    O.OFFNO as store_id,
    O.OFFNAM as store_name,
    C.CLNTNAM1 as warehouse_name,
    M.MATNO as item_code,
    M.MATNAM as item_description,
    CD.QTY as actual_qty,
    CD.PREVQTY as previous_qty,
    CD.QTY - CD.PREVQTY as qty_difference,
    M.EMPPRICE as unit_cost,
    CD.QTY * M.EMPPRICE as correct_total,
    CD.PREVQTY * M.EMPPRICE as query1_total,
    (CD.QTY - CD.PREVQTY) * M.EMPPRICE as amount_variance,
    CH.UPDSTMP as transaction_date
FROM WINPROD.CMSHDR CH
    INNER JOIN WINPROD.CMSDTL CD ON CH.GID = CD.CMSID
    INNER JOIN WINPROD.MATERIAL M ON CD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON CD.TREEID = O.TREEID
    INNER JOIN WINPROD.CLIENT C ON CD.CLIENTID = C.GID
WHERE CH.CMSSTATUS IN ('C', 'X')
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND C.STATUS = 'A'
    AND CD.QTY <> CD.PREVQTY  -- ← Records with variance
    AND TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE];

-- Impact:
-- Query 1: Uses PREVQTY for calculations
-- Query 2: Uses QTY for calculations
-- Variance: Different amounts where QTY ≠ PREVQTY
```

**What PREVQTY Represents:**
- Likely the "previous quantity" before adjustment
- Or possibly a pre-transfer quantity snapshot
- **Need business clarification on correct field**

**Example Scenario:**
- Store 101 returns 80 units to warehouse
- CD.QTY = 80 (actual transfer quantity)
- CD.PREVQTY = 75 (previous or adjusted quantity)
- Unit cost = $10
- **Query 1 shows:** 75 units × $10 = $750
- **Query 2 shows:** 80 units × $10 = $800
- **Variance:** -5 units, -$50 in Query 1

---

### 6. Transactions with Header/Detail Timestamp Differences - **DATE RANGE VARIANCE**

**Prediction:** Records where header and detail dates differ may appear in **different periods**

**Identification Criteria:**
```sql
-- These transactions MAY fall in different date ranges:

-- SHOP TO SHOP with date variance
SELECT 
    'SHOP TO SHOP' as transaction_type,
    CH.GID as document_id,
    O.OFFNO as store_id,
    M.MATNO as item_code,
    TRUNC(CH.UPDSTMP) as header_date,
    TRUNC(CD.UPDSTMP) as detail_date,
    CD.QTY,
    CASE 
        WHEN TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE] THEN 'Y'
        ELSE 'N'
    END as in_period_by_header,
    CASE 
        WHEN TRUNC(CD.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE] THEN 'Y'
        ELSE 'N'
    END as in_period_by_detail
FROM WINPROD.CMSHDR CH
    INNER JOIN WINPROD.CMSDTL CD ON CH.GID = CD.CMSID
    INNER JOIN WINPROD.MATERIAL M ON CD.MATNO = M.MATNO
    INNER JOIN WINPROD.OFFICE O ON CD.TREEID = O.TREEID
WHERE CD.DTLSTATUS = 'C'
    AND TRUNC(CH.UPDSTMP) <> TRUNC(CD.UPDSTMP)  -- ← Dates differ
    AND (
        TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE]
        OR TRUNC(CD.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE]
    );

-- SHOP TO WH with date variance
SELECT 
    'SHOP TO WH' as transaction_type,
    CH.GID as document_id,
    O.OFFNO as store_id,
    M.MATNO as item_code,
    TRUNC(CH.UPDSTMP) as header_date,
    TRUNC(CD.UPDSTMP) as detail_date,
    CD.QTY,
    CASE 
        WHEN TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE] THEN 'Y'
        ELSE 'N'
    END as in_period_by_header,
    CASE 
        WHEN TRUNC(CD.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE] THEN 'Y'
        ELSE 'N'
    END as in_period_by_detail
FROM WINPROD.CMSHDR CH
    INNER JOIN WINPROD.CMSDTL CD ON CH.GID = CD.CMSID
    INNER JOIN WINPROD.MATERIAL M ON CD.MATNO = M.MATNO
    INNER JOIN WINPROD.CLIENT C ON CD.CLIENTID = C.GID
    INNER JOIN WINPROD.OFFICE O ON CD.TREEID = O.TREEID
WHERE CH.CMSSTATUS IN ('C', 'X')
    AND TRUNC(CH.UPDSTMP) <> TRUNC(CD.UPDSTMP)  -- ← Dates differ
    AND (
        TRUNC(CH.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE]
        OR TRUNC(CD.UPDSTMP) BETWEEN [START_DATE] AND [END_DATE]
    );

-- Impact:
-- Query 1: Uses CD.UPDSTMP (detail date)
-- Query 2: Uses CH.UPDSTMP (header date)
-- Variance: Records may appear in different reporting periods
```

**Scenarios:**

1. **Multi-day processing**
   - Header created on Day 1 (order/transfer initiated)
   - Details finalized on Day 2 (completion)

2. **Month-end cutoff**
   - Header: 2025-11-30 23:55:00
   - Detail: 2025-12-01 00:05:00
   - Appears in November (Query 2) or December (Query 1)

3. **Bulk updates**
   - Header updated once
   - Details updated individually at different times

**Example Scenario:**
- Shop to Shop transfer initiated on 2025-11-30
- CH.UPDSTMP = 2025-11-30 23:50:00
- CD.UPDSTMP = 2025-12-01 00:10:00 (completed after midnight)
- Date range: 2025-11-01 to 2025-11-30
- **Query 1:** Uses detail date (Dec 1) → Excluded from November
- **Query 2:** Uses header date (Nov 30) → Included in November
- **Variance:** Record missing from Query 1 for November period

---

## Summary Table: Predicted Variances

| Transaction Type | Variance Type | Query 1 Count | Query 2 Count | Direction |
|-----------------|---------------|---------------|---------------|-----------|
| **SHOP TO SHOP** | Duplication | 2N | N | Query 1 > Query 2 |
| **SALE without COUPONCODE** | Missing | 0 | M | Query 1 < Query 2 |
| **RETURN without COUPONCODE** | Missing | 0 | R | Query 1 < Query 2 |
| **CANCEL without COUPONCODE** | Missing | 0 | C | Query 1 < Query 2 |
| **INV without EXPID1** | Missing | 0 | I | Query 1 < Query 2 |
| **WH TO SHOP without log** | Missing | 0 | W | Query 1 < Query 2 |
| **SHOP TO WH (qty variance)** | Amount | Different totals | Different totals | Amounts differ |
| **Date range boundary** | Timing | Different | Different | Period shift |

**Legend:**
- N = Total SHOP TO SHOP transfers
- M = Sales without COUPONCODE
- R = Returns without COUPONCODE
- C = Cancels without COUPONCODE
- I = Inventory adjustments without EXPID1
- W = WH TO SHOP without cost update log

---

## Net Variance Formula

```
Query1_Total_Records = Query2_Total_Records + N - M - R - C - I - W ± T

Where:
  N = SHOP TO SHOP duplication (adds records to Query 1)
  M, R, C, I, W = Missing transaction categories (reduce Query 1)
  T = Date range boundary timing differences
```

**Likely Outcome:**
- If N > (M + R + C + I + W): Query 1 will have MORE records
- If N < (M + R + C + I + W): Query 1 will have FEWER records
- If N ≈ (M + R + C + I + W): Query counts may be similar but composition is wrong

---

## How to Identify Variance Transactions in Your Data

### Step 1: Run Variance Detection Queries
Use the SQL queries in this document with your actual date range to identify:
1. All SHOP TO SHOP transfers (will be doubled)
2. Sales/Returns/Cancels without COUPONCODE
3. Inventory without EXPID1
4. WH TO SHOP without cost log entry
5. SHOP TO WH with qty ≠ prevqty
6. Records with header/detail date mismatches

### Step 2: Quantify Impact
```sql
-- Summary of variance by category
SELECT 
    'SHOP TO SHOP (doubled)' as category,
    COUNT(*) as affected_records,
    COUNT(*) as query1_extra_records
FROM (/* SHOP TO SHOP query */)
UNION ALL
SELECT 
    'SALE without COUPONCODE',
    COUNT(*),
    -COUNT(*) as query1_missing
FROM (/* Sales query */)
UNION ALL
SELECT 
    'INV without EXPID1',
    COUNT(*),
    -COUNT(*)
FROM (/* Inventory query */)
-- Continue for all categories...
```

### Step 3: Reconcile Total
```sql
-- Expected variance
SELECT 
    SUM(CASE WHEN variance_type = 'ADD' THEN affected_records ELSE 0 END) as query1_extras,
    SUM(CASE WHEN variance_type = 'SUBTRACT' THEN affected_records ELSE 0 END) as query1_missing,
    SUM(CASE WHEN variance_type = 'ADD' THEN affected_records ELSE 0 END) -
    SUM(CASE WHEN variance_type = 'SUBTRACT' THEN affected_records ELSE 0 END) as net_variance
FROM variance_summary;
```

---

## Recommendations

1. **For Complete Accuracy**: Use Query 2
2. **For Reconciliation**: Run variance detection queries to quantify impact
3. **For Migration**: Apply corrections from CORRECTED_QUERY_1.sql
4. **For Validation**: Use VALIDATION_QUERIES.sql with your data

---

## Business Impact

### High-Risk Variance Categories:
1. **SHOP TO SHOP duplication** → Inflated transfer volumes, incorrect inventory flow reporting
2. **Missing sales without COUPONCODE** → Understated revenue and unit sales
3. **Missing WH TO SHOP** → Incomplete delivery tracking, procurement analysis gaps

### Medium-Risk Variance Categories:
4. **Missing inventory adjustments** → Incomplete stock take reporting
5. **SHOP TO WH quantity variance** → Incorrect return volumes if prevqty is wrong field

### Low-Risk Variance Categories:
6. **Date boundary timing** → Period classification only, same annual totals

---

## Next Steps

1. **Run variance detection queries** on your actual data for specific date range
2. **Quantify the impact** for each category
3. **Review business rules** to confirm correct field usage (qty vs prevqty)
4. **Implement corrected query** or migrate to Query 2
5. **Validate results** match expected business volumes
