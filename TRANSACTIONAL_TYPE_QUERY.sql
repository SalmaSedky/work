-- =====================================================================
-- TRANSACTIONAL TYPE QUERY
-- =====================================================================
-- Purpose: Query to retrieve order and basket data with transactional_type classification
-- Source Tables: 
--   - DEV_STG..STG_ORDER_REQUEST_VIEW
--   - DEV_STG..STG_REQUEST_BASKET_VW
-- Date Range: 2025-01-01 to 2025-12-31
-- Channel: CHANNEL_ID = 3
-- Status: request_status = 'DONE'
-- =====================================================================

SELECT 
    IS_MNP,
    PRODUCT_TYPE,
    ACTON,
    -- New transactional_type column with business logic
    CASE
        -- Rule 1: MNP Flag takes highest priority
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
        
        -- Default: Return NULL or original values for unmatched cases
        ELSE NULL
    END AS transactional_type
    
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
-- EXPECTED OUTPUT MAPPING
-- =====================================================================
-- Based on the provided sample data, expected results:
--
-- IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type
-- -------|--------------|-------------------------------|-------------------
-- N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL
-- N      | Business     | NEW_ACCOUNT_ACTION            | NULL (Business is not Postpaid/Prepaid)
-- N      | Business     | REREGISTRATION_ACTION         | REREGISTRATION
-- N      | Postpaid     | AUCTION_ACTION                | NULL
-- N      | Postpaid     | NEW_ACCOUNT_ACTION            | new postpaid
-- N      | Postpaid     | MIGRATION_ACTION              | Migration
-- N      | Postpaid     | REREGISTRATION_ACTION         | REREGISTRATION
-- N      | Hassantuk    | HASSANTUK_ACTION              | NULL
-- N      | Prepaid      | CESSATION_ACTION              | NULL
-- N      | Prepaid      | NEW_ACCOUNT_ACTION            | new prepaid
-- N      | Prepaid      | REREGISTRATION_ACTION         | REREGISTRATION
-- N      | BUlitmate    | REREGISTRATION_ACTION         | REREGISTRATION
-- N      | Fixed        | MANAGE_SERVICE_ACTION         | elife
-- N      | Fixed        | NEW_ACCOUNT_ACTION            | elife
-- Y      | Prepaid      | NEW_ACCOUNT_ACTION            | MNP (MNP flag takes priority)
-- Y      | Business     | NEW_ACCOUNT_ACTION            | MNP (MNP flag takes priority)
-- Y      | Postpaid     | NEW_ACCOUNT_ACTION            | MNP (MNP flag takes priority)
-- =====================================================================


-- =====================================================================
-- ALTERNATIVE VERSION: Include all columns from source
-- =====================================================================
-- If you need all original columns plus transactional_type:
/*
SELECT 
    ORD.order_id,
    ORD.is_mnp AS IS_MNP,
    RB.basket_id,
    RB.product_type AS PRODUCT_TYPE,
    RB.ACTON,
    -- New transactional_type column
    CASE
        WHEN ORD.is_mnp = 'Y' THEN 'MNP'
        WHEN RB.ACTON = 'NEW_ACCOUNT_ACTION' AND RB.product_type = 'Postpaid' THEN 'new postpaid'
        WHEN RB.ACTON = 'NEW_ACCOUNT_ACTION' AND RB.product_type = 'Prepaid' THEN 'new prepaid'
        WHEN RB.ACTON = 'MIGRATION_ACTION' THEN 'Migration'
        WHEN RB.ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
        WHEN RB.product_type = 'Fixed' THEN 'elife'
        ELSE NULL
    END AS transactional_type
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
*/
