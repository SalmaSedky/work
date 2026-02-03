-- =====================================================================
-- TRANSACTIONAL TYPE QUERY WITH CLASSIFICATION IDs
-- =====================================================================
-- Purpose: Query to retrieve order and basket data with PRTL_SLS_TP_ID
--          (Portal Sales Type ID) from CL_SCM/CL_CV classification tables
-- Source Tables: 
--   - DEV_STG..STG_ORDER_REQUEST_VIEW
--   - DEV_STG..STG_REQUEST_BASKET_VW
--   - dev_sor.ADMIN.CL_SCM (Classification Schema)
--   - dev_sor.ADMIN.CL_CV (Classification Values)
-- Date Range: 2025-01-01 to 2025-12-31
-- Channel: CHANNEL_ID = 3
-- Status: request_status = 'DONE'
-- =====================================================================

SELECT 
    IS_MNP,
    PRODUCT_TYPE,
    ACTON,
    -- Portal Sales Type ID using classification lookup
    CASE
        -- Rule 0: Business Ultimate (highest priority for Business product types)
        WHEN PRODUCT_TYPE IN ('BUlitmate', 'Business') THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Business Ultimate'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 1: MNP Flag takes highest priority
        WHEN IS_MNP = 'Y' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'MNP'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 2: New Postpaid Account
        WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'New Postpaid'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 3: New Prepaid Account
        WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'New Prepaid'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 4: Migration Action
        WHEN ACTON = 'MIGRATION_ACTION' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Migration'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 5: Reregistration Action
        WHEN ACTON = 'REREGISTRATION_ACTION' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Portal Reregistration'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Rule 6: Fixed Product Type (elife)
        WHEN PRODUCT_TYPE = 'Fixed' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, 
                  dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Elife'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        
        -- Default: Return NULL for unmatched cases
        ELSE NULL
    END AS PRTL_SLS_TP_ID
    
FROM (
    SELECT DISTINCT 
        IS_MNP, 
        PRODUCT_TYPE, 
        ACTON 
    FROM (
        -- Order Request Data
        SELECT  
            order_id, 
            is_mnp 
        FROM DEV_STG..STG_ORDER_REQUEST_VIEW 
        WHERE CHANNEL_ID = 3 
            AND CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59' 
            AND request_status = 'DONE'
    ) ORD
    LEFT JOIN (
        -- Request Basket Data
        SELECT DISTINCT 
            order_id,
            basket_id,
            product_type,
            ACTON 
        FROM DEV_STG..STG_REQUEST_BASKET_VW 
        WHERE CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59'
    ) RB
    ON ORD.order_id = RB.order_id
) X
ORDER BY IS_MNP, PRODUCT_TYPE, ACTON;


-- =====================================================================
-- ALTERNATIVE: USING JOIN FOR BETTER PERFORMANCE
-- =====================================================================
-- This version pre-loads classification IDs and uses JOINs
-- More efficient for large datasets

WITH classification_ids AS (
    SELECT 
        cv.CL_NM,
        cv.CL_CV_ID
    FROM dev_sor.ADMIN.CL_SCM scm
    JOIN dev_sor.ADMIN.CL_CV cv ON scm.CL_SCM_ID = cv.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type'
      AND cv.ACTIVE_FLAG = 'Y'
),
transaction_data AS (
    SELECT DISTINCT 
        IS_MNP, 
        PRODUCT_TYPE, 
        ACTON 
    FROM (
        SELECT  
            order_id, 
            is_mnp 
        FROM DEV_STG..STG_ORDER_REQUEST_VIEW 
        WHERE CHANNEL_ID = 3 
            AND CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59' 
            AND request_status = 'DONE'
    ) ORD
    LEFT JOIN (
        SELECT DISTINCT 
            order_id,
            basket_id,
            product_type,
            ACTON 
        FROM DEV_STG..STG_REQUEST_BASKET_VW 
        WHERE CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59'
    ) RB
    ON ORD.order_id = RB.order_id
)
SELECT 
    td.IS_MNP,
    td.PRODUCT_TYPE,
    td.ACTON,
    -- Determine classification and get ID
    CASE
        WHEN td.PRODUCT_TYPE IN ('BUlitmate', 'Business') THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'Business Ultimate')
        WHEN td.IS_MNP = 'Y' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'MNP')
        WHEN td.ACTON = 'NEW_ACCOUNT_ACTION' AND td.PRODUCT_TYPE = 'Postpaid' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'New Postpaid')
        WHEN td.ACTON = 'NEW_ACCOUNT_ACTION' AND td.PRODUCT_TYPE = 'Prepaid' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'New Prepaid')
        WHEN td.ACTON = 'MIGRATION_ACTION' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'Migration')
        WHEN td.ACTON = 'REREGISTRATION_ACTION' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'Portal Reregistration')
        WHEN td.PRODUCT_TYPE = 'Fixed' THEN 
            (SELECT CL_CV_ID FROM classification_ids WHERE CL_NM = 'Elife')
        ELSE NULL
    END :: BIGINT AS PRTL_SLS_TP_ID
FROM transaction_data td
ORDER BY td.IS_MNP, td.PRODUCT_TYPE, td.ACTON;


-- =====================================================================
-- ALTERNATIVE: FULL QUERY WITH ALL COLUMNS
-- =====================================================================
-- This version includes order_id and basket_id for complete data

SELECT 
    ORD.order_id,
    ORD.is_mnp AS IS_MNP,
    RB.basket_id,
    RB.product_type AS PRODUCT_TYPE,
    RB.ACTON,
    -- Portal Sales Type ID
    CASE
        WHEN RB.product_type IN ('BUlitmate', 'Business') THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Business Ultimate'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN ORD.is_mnp = 'Y' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'MNP'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN RB.ACTON = 'NEW_ACCOUNT_ACTION' AND RB.product_type = 'Postpaid' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'New Postpaid'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN RB.ACTON = 'NEW_ACCOUNT_ACTION' AND RB.product_type = 'Prepaid' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'New Prepaid'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN RB.ACTON = 'MIGRATION_ACTION' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Migration'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN RB.ACTON = 'REREGISTRATION_ACTION' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Portal Reregistration'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        WHEN RB.product_type = 'Fixed' THEN 
            (SELECT B.CL_CV_ID 
             FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
             WHERE A.CL_SCM_NM = 'Portal Transaction Type'
               AND A.CL_SCM_ID = B.CL_SCM_ID
               AND B.CL_NM = 'Elife'
               AND B.ACTIVE_FLAG = 'Y'
            ) :: BIGINT
        ELSE NULL
    END AS PRTL_SLS_TP_ID
FROM (
    SELECT  
        order_id, 
        is_mnp 
    FROM DEV_STG..STG_ORDER_REQUEST_VIEW 
    WHERE CHANNEL_ID = 3 
        AND CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59' 
        AND request_status = 'DONE'
) ORD
LEFT JOIN (
    SELECT DISTINCT 
        order_id,
        basket_id,
        product_type,
        ACTON 
    FROM DEV_STG..STG_REQUEST_BASKET_VW 
    WHERE CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59'
) RB
ON ORD.order_id = RB.order_id
ORDER BY ORD.order_id, RB.basket_id;

-- =====================================================================
-- EXPECTED OUTPUT MAPPING
-- =====================================================================
-- Based on the provided sample data, expected results with IDs:
--
-- IS_MNP | PRODUCT_TYPE | ACTON                         | PRTL_SLS_TP_ID | Classification Name
-- -------|--------------|-------------------------------|----------------|--------------------
-- N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | 1              | Business Ultimate
-- N      | Business     | NEW_ACCOUNT_ACTION            | 1              | Business Ultimate
-- N      | BUlitmate    | REREGISTRATION_ACTION         | 1              | Business Ultimate
-- N      | Postpaid     | AUCTION_ACTION                | NULL           | (Unclassified)
-- N      | Postpaid     | NEW_ACCOUNT_ACTION            | 4              | New Postpaid
-- N      | Postpaid     | MIGRATION_ACTION              | 5              | Migration
-- N      | Postpaid     | REREGISTRATION_ACTION         | 6              | Portal Reregistration
-- N      | Fixed        | MANAGE_SERVICE_ACTION         | 7              | Elife
-- N      | Fixed        | NEW_ACCOUNT_ACTION            | 7              | Elife
-- N      | Prepaid      | CESSATION_ACTION              | NULL           | (Unclassified)
-- N      | Prepaid      | NEW_ACCOUNT_ACTION            | 3              | New Prepaid
-- N      | Prepaid      | REREGISTRATION_ACTION         | 6              | Portal Reregistration
-- Y      | Prepaid      | NEW_ACCOUNT_ACTION            | 2              | MNP
-- Y      | Business     | NEW_ACCOUNT_ACTION            | 2              | MNP
-- Y      | Postpaid     | NEW_ACCOUNT_ACTION            | 2              | MNP
-- =====================================================================

-- =====================================================================
-- VALIDATION QUERY
-- =====================================================================
-- Verify that all IDs resolve to correct classification names

SELECT 
    X.IS_MNP,
    X.PRODUCT_TYPE,
    X.ACTON,
    X.PRTL_SLS_TP_ID,
    cv.CL_NM AS classification_name,
    cv.CL_CODE AS classification_code
FROM (
    -- Your main query here
    SELECT DISTINCT 
        IS_MNP, 
        PRODUCT_TYPE, 
        ACTON,
        CASE
            WHEN PRODUCT_TYPE IN ('BUlitmate', 'Business') THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'Business Ultimate' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN IS_MNP = 'Y' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'MNP' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'New Postpaid' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'New Prepaid' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN ACTON = 'MIGRATION_ACTION' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'Migration' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN ACTON = 'REREGISTRATION_ACTION' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'Portal Reregistration' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            WHEN PRODUCT_TYPE = 'Fixed' THEN 
                (SELECT B.CL_CV_ID FROM dev_sor.ADMIN.CL_SCM A, dev_sor.ADMIN.CL_CV B
                 WHERE A.CL_SCM_NM = 'Portal Transaction Type' AND A.CL_SCM_ID = B.CL_SCM_ID
                   AND B.CL_NM = 'Elife' AND B.ACTIVE_FLAG = 'Y') :: BIGINT
            ELSE NULL
        END AS PRTL_SLS_TP_ID
    FROM (
        SELECT  
            order_id, 
            is_mnp 
        FROM DEV_STG..STG_ORDER_REQUEST_VIEW 
        WHERE CHANNEL_ID = 3 
            AND CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59' 
            AND request_status = 'DONE'
    ) ORD
    LEFT JOIN (
        SELECT DISTINCT 
            order_id,
            basket_id,
            product_type,
            ACTON 
        FROM DEV_STG..STG_REQUEST_BASKET_VW 
        WHERE CREATED_DATE_STAMP BETWEEN '2025-01-01' AND '2025-12-31 23:59:59'
    ) RB
    ON ORD.order_id = RB.order_id
) X
LEFT JOIN dev_sor.ADMIN.CL_CV cv ON X.PRTL_SLS_TP_ID = cv.CL_CV_ID
ORDER BY X.IS_MNP, X.PRODUCT_TYPE, X.ACTON;
