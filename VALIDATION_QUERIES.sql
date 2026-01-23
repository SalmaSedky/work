-- VALIDATION QUERIES TO IDENTIFY DISCREPANCIES
-- Run these queries to quantify the gaps between Query 1 and Query 2

-- ============================================================================
-- 1. SHOP TO SHOP DUPLICATION CHECK
-- ============================================================================
-- This should show Query 1 has approximately 2x the SHOP TO SHOP records

-- Count in Query 1 (both OUTBOUND and INBOUND)
SELECT 'Query 1 - SHOP TO SHOP Total' as metric, COUNT(*) as record_count
FROM (
    -- OUTBOUND
    SELECT m.matno, ch.gid, cd.qty
    FROM WINPROD.cmsdtl cd
        INNER JOIN WINPROD.material m ON cd.matno = m.matno AND m.TREEID IN (0,1)
        INNER JOIN WINPROD.office o ON cd.treeid = o.treeid
        INNER JOIN WINPROD.office o1 ON cd.dsttreeid = o1.treeid
        INNER JOIN WINPROD.cmshdr ch ON cd.cmsid = ch.gid
    WHERE o.status = 'A' 
        AND m.status = 'A' 
        AND o1.status = 'A'
        AND cd.dtlstatus = 'C'
        AND TRUNC(cd.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                                  AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    
    UNION ALL
    
    -- INBOUND (duplicate records)
    SELECT m.matno, ch.gid, cd.qty
    FROM WINPROD.cmsdtl cd
        INNER JOIN WINPROD.material m ON cd.matno = m.matno AND m.TREEID IN (0,1)
        INNER JOIN WINPROD.office o ON cd.treeid = o.treeid
        INNER JOIN WINPROD.office o1 ON cd.dsttreeid = o1.treeid
        INNER JOIN WINPROD.cmshdr ch ON cd.cmsid = ch.gid
    WHERE o.status = 'A' 
        AND m.status = 'A' 
        AND o1.status = 'A'
        AND cd.dtlstatus = 'C'
        AND TRUNC(cd.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                                  AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
)
UNION ALL

-- Count in Query 2 (single record per transfer)
SELECT 'Query 2 - SHOP TO SHOP Total' as metric, COUNT(*) as record_count
FROM WINPROD.CMSHDR HDR
    INNER JOIN WINPROD.CMSDTL DTL ON HDR.GID = DTL.CMSID
    INNER JOIN WINPROD.MATERIAL M ON DTL.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON DTL.TREEID = O.TREEID
    INNER JOIN WINPROD.OFFICE OD ON DTL.DSTTREEID = OD.TREEID
WHERE DTL.DTLSTATUS = 'C'
    AND TRUNC(HDR.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                               AND TO_DATE('2025-11-30', 'YYYY-MM-DD');

-- Expected: Query 1 count ≈ 2x Query 2 count

-- ============================================================================
-- 2. MISSING SALES WITHOUT COUPONCODE
-- ============================================================================
-- Identifies sales/returns/cancels excluded from Query 1

SELECT 
    'Sales WITHOUT COUPONCODE (missing from Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(ROUND(VD.AM * NVL(VD.EMPPRICE, M.EMPPRICE), 2)) as total_amount
FROM WINPROD.VOUHDR VH
    INNER JOIN WINPROD.VOUDTL VD ON VH.JOUID = VD.JOUID AND VH.TREEID = VD.TREEID
    INNER JOIN WINPROD.MATERIAL M ON M.GID = VD.MATID AND M.STOCKCTRL = 'Y'
WHERE VH.VOUTYPE IN ('V', 'R', 'S')
    AND VD.COUPONCODE IS NULL  -- These are EXCLUDED from Query 1
    AND TRUNC(VH.POSDAT) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                             AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
UNION ALL
SELECT 
    'Sales WITH COUPONCODE (included in Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(ROUND(VD.AM * NVL(VD.EMPPRICE, M.EMPPRICE), 2)) as total_amount
FROM WINPROD.VOUHDR VH
    INNER JOIN WINPROD.VOUDTL VD ON VH.JOUID = VD.JOUID AND VH.TREEID = VD.TREEID
    INNER JOIN WINPROD.MATERIAL M ON M.GID = VD.MATID AND M.STOCKCTRL = 'Y'
WHERE VH.VOUTYPE IN ('V', 'R', 'S')
    AND VD.COUPONCODE IS NOT NULL  -- These are INCLUDED in Query 1
    AND TRUNC(VH.POSDAT) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                             AND TO_DATE('2025-11-30', 'YYYY-MM-DD');

-- Expected: Significant number of records without COUPONCODE

-- ============================================================================
-- 3. MISSING INVENTORY ADJUSTMENTS WITHOUT EXPID1
-- ============================================================================
-- Identifies inventory adjustments excluded from Query 1

SELECT 
    'Inventory WITHOUT EXPID1 (missing from Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(ROUND(MV.QTY * M.EMPPRICE, 2)) as total_amount
FROM WINPROD.MATMOVE MV
    INNER JOIN WINPROD.MATMOVETYPE MVT ON MV.MVTYPEID = MVT.GID AND MVT.MMTCODE IN ('INV')
    INNER JOIN WINPROD.MATERIAL M ON MV.MATID = M.GID AND M.STOCKCTRL = 'Y'
WHERE MV.STATUS = 'O' 
    AND MV.MVNO2 IS NOT NULL
    AND MV.QTY <> 0
    AND MV.EXPID1 IS NULL  -- These are EXCLUDED from Query 1
    AND TRUNC(MV.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                              AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    AND ROUND(MV.QTY * M.EMPPRICE, 2) <> 0
UNION ALL
SELECT 
    'Inventory WITH EXPID1 (included in Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(ROUND(MV.QTY * M.EMPPRICE, 2)) as total_amount
FROM WINPROD.MATMOVE MV
    INNER JOIN WINPROD.MATMOVETYPE MVT ON MV.MVTYPEID = MVT.GID AND MVT.MMTCODE IN ('INV')
    INNER JOIN WINPROD.MATERIAL M ON MV.MATID = M.GID AND M.STOCKCTRL = 'Y'
WHERE MV.STATUS = 'O' 
    AND MV.MVNO2 IS NOT NULL
    AND MV.QTY <> 0
    AND MV.EXPID1 IS NOT NULL  -- These are INCLUDED in Query 1
    AND TRUNC(MV.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                              AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    AND ROUND(MV.QTY * M.EMPPRICE, 2) <> 0;

-- Expected: Some records without EXPID1

-- ============================================================================
-- 4. WH TO SHOP - MISSING RECORDS WITHOUT COST UPDATE LOG
-- ============================================================================
-- Identifies WH TO SHOP deliveries excluded from Query 1

SELECT 
    'WH TO SHOP WITHOUT cost log (missing from Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(OD.DELQTY * M.EMPPRICE) as total_amount
FROM WINPROD.ORDDTL OD
    INNER JOIN WINPROD.MATERIAL M ON OD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON OD.TREEID = O.TREEID
WHERE OD.ORDSTATUS = 'C'
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND TRUNC(OD.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                              AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    AND NOT EXISTS (
        -- Records NOT in cost update log
        SELECT 1 
        FROM WINPROD.ETSUAE_COST_UPDATE_LOG LG
        WHERE LG.WINCASH_ORDER = OD.ORDID 
          AND LG.ITEM_CODE = OD.MATNO
    )
UNION ALL
SELECT 
    'WH TO SHOP WITH cost log (included in Query 1)' as metric,
    COUNT(*) as record_count,
    SUM(OD.DELQTY * M.EMPPRICE) as total_amount
FROM WINPROD.ORDDTL OD
    INNER JOIN WINPROD.MATERIAL M ON OD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON OD.TREEID = O.TREEID
WHERE OD.ORDSTATUS = 'C'
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND TRUNC(OD.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                              AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    AND EXISTS (
        -- Records IN cost update log
        SELECT 1 
        FROM WINPROD.ETSUAE_COST_UPDATE_LOG LG
        WHERE LG.WINCASH_ORDER = OD.ORDID 
          AND LG.ITEM_CODE = OD.MATNO
    );

-- Expected: Some deliveries not yet in cost update log

-- ============================================================================
-- 5. SHOP TO WH - QUANTITY COMPARISON (prevqty vs qty)
-- ============================================================================
-- Compares prevqty and qty to identify discrepancies

SELECT 
    'SHOP TO WH with qty ≠ prevqty' as metric,
    COUNT(*) as record_count,
    SUM(CD.QTY * M.EMPPRICE) as total_using_qty,
    SUM(CD.PREVQTY * M.EMPPRICE) as total_using_prevqty,
    SUM((CD.QTY - CD.PREVQTY) * M.EMPPRICE) as difference
FROM WINPROD.CMSHDR CH
    INNER JOIN WINPROD.CMSDTL CD ON CH.GID = CD.CMSID
    INNER JOIN WINPROD.MATERIAL M ON CD.MATNO = M.MATNO AND M.TREEID IN (0,1)
    INNER JOIN WINPROD.OFFICE O ON CD.TREEID = O.TREEID
    INNER JOIN WINPROD.CLIENT C ON CD.CLIENTID = C.GID
WHERE CH.CMSSTATUS IN ('C', 'X')
    AND O.STATUS = 'A'
    AND M.STATUS = 'A'
    AND C.STATUS = 'A'
    AND TRUNC(CH.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                              AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    AND CD.QTY <> CD.PREVQTY;  -- Where they differ

-- Expected: Identify if prevqty and qty are different

-- ============================================================================
-- 6. DATE RANGE COMPARISON - HEADER vs DETAIL TIMESTAMPS
-- ============================================================================
-- Shows records that fall in different periods based on timestamp used

-- SHOP TO SHOP - records with different header/detail dates
SELECT 
    'SHOP TO SHOP: Header and Detail dates differ' as metric,
    COUNT(*) as record_count
FROM WINPROD.CMSHDR HDR
    INNER JOIN WINPROD.CMSDTL DTL ON HDR.GID = DTL.CMSID
WHERE TRUNC(HDR.UPDSTMP) <> TRUNC(DTL.UPDSTMP)
    AND DTL.DTLSTATUS = 'C'
    AND (
        TRUNC(HDR.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                               AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
        OR
        TRUNC(DTL.UPDSTMP) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') 
                               AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
    );

-- Expected: Some records where header and detail dates differ

-- ============================================================================
-- 7. OVERALL RECORD COUNT COMPARISON
-- ============================================================================
-- High-level comparison of total records

SELECT 
    'ESTIMATED Query 1 Total' as query_name,
    (SELECT COUNT(*) FROM (/* Insert full Query 1 here */)) as total_records
UNION ALL
SELECT 
    'ESTIMATED Query 2 Total' as query_name,
    (SELECT COUNT(*) FROM (/* Insert full Query 2 here */)) as total_records;

-- ============================================================================
-- 8. TRANSACTION TYPE BREAKDOWN
-- ============================================================================
-- Compare counts by transaction type

-- For Query 1 - breakdown by transaction type
SELECT 
    'Query 1 - ' || Transaction_type as transaction_type,
    COUNT(*) as record_count,
    SUM(TO_NUMBER(REGEXP_REPLACE(Total, '[^0-9.-]', ''))) as total_amount
FROM (
    /* Insert full Query 1 here */
)
GROUP BY Transaction_type
ORDER BY Transaction_type;

-- For Query 2 - breakdown by transaction type  
SELECT 
    'Query 2 - ' || TRANSACTION_TYPE as transaction_type,
    COUNT(*) as record_count,
    SUM(TOTAL_COST) as total_amount
FROM (
    /* Insert full Query 2 here */
)
GROUP BY TRANSACTION_TYPE
ORDER BY TRANSACTION_TYPE;

-- ============================================================================
-- SUMMARY RECOMMENDATIONS
-- ============================================================================
/*
Run these validation queries to:

1. Quantify the SHOP TO SHOP duplication (expect 2x in Query 1)
2. Identify missing sales without COUPONCODE
3. Identify missing inventory without EXPID1
4. Identify missing WH TO SHOP without cost update log
5. Compare qty vs prevqty usage in SHOP TO WH
6. Identify date range issues from header vs detail timestamps
7. Compare overall record counts
8. Break down by transaction type

Use results to:
- Document the impact of each discrepancy
- Justify the corrections to Query 1
- Validate that Query 2 is more complete
- Support migration from Query 1 to Query 2
*/
