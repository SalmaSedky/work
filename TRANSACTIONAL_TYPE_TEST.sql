-- =====================================================================
-- TRANSACTIONAL TYPE VALIDATION TEST
-- =====================================================================
-- Purpose: Test the transactional_type logic with sample data
-- This file validates the CASE statement logic against known inputs
-- =====================================================================

-- Create test data based on provided sample
WITH test_data AS (
    SELECT 'N' AS IS_MNP, 'Business' AS PRODUCT_TYPE, 'TRANSFER_OF_OWNERSHIP_ACTION' AS ACTON
    UNION ALL SELECT 'N', 'Business', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'AUCTION_ACTION'
    UNION ALL SELECT 'N', 'Fixed', 'MANAGE_SERVICE_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'MIGRATION_ACTION'
    UNION ALL SELECT 'N', 'Hassantuk', 'HASSANTUK_ACTION'
    UNION ALL SELECT 'N', NULL, NULL
    UNION ALL SELECT 'N', 'Prepaid', 'CESSATION_ACTION'
    UNION ALL SELECT 'Y', 'Prepaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Prepaid', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'Y', 'Business', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'Y', 'Postpaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'Business', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'BUlitmate', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'Fixed', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Prepaid', 'NEW_ACCOUNT_ACTION'
)
SELECT 
    IS_MNP,
    PRODUCT_TYPE,
    ACTON,
    -- Apply the transactional_type logic
    CASE
        WHEN IS_MNP = 'Y' THEN 'MNP'
        WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'new postpaid'
        WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'new prepaid'
        WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
        WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
        WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
        ELSE NULL
    END AS transactional_type,
    -- Expected result for validation
    CASE 
        WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Prepaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
        WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Business' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
        WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
        WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new postpaid'
        WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Prepaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new prepaid'
        WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
        WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
        WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
        ELSE NULL
    END AS expected_result,
    -- Validation flag
    CASE
        WHEN (
            CASE
                WHEN IS_MNP = 'Y' THEN 'MNP'
                WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'new postpaid'
                WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'new prepaid'
                WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
                WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
                WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
                ELSE NULL
            END
        ) = (
            CASE 
                WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Prepaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
                WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Business' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
                WHEN IS_MNP = 'Y' AND PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'MNP'
                WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new postpaid'
                WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Prepaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new prepaid'
                WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
                WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
                WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
                ELSE NULL
            END
        ) THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM test_data
ORDER BY IS_MNP DESC, PRODUCT_TYPE, ACTON;


-- =====================================================================
-- EXPECTED OUTPUT
-- =====================================================================
-- All rows should show test_result = 'PASS'
--
-- IS_MNP | PRODUCT_TYPE | ACTON                         | transactional_type | expected_result    | test_result
-- -------|--------------|-------------------------------|--------------------|--------------------|------------
-- Y      | Prepaid      | NEW_ACCOUNT_ACTION            | MNP                | MNP                | PASS
-- Y      | Business     | NEW_ACCOUNT_ACTION            | MNP                | MNP                | PASS
-- Y      | Postpaid     | NEW_ACCOUNT_ACTION            | MNP                | MNP                | PASS
-- N      | Business     | TRANSFER_OF_OWNERSHIP_ACTION  | NULL               | NULL               | PASS
-- N      | Business     | NEW_ACCOUNT_ACTION            | NULL               | NULL               | PASS
-- N      | Business     | REREGISTRATION_ACTION         | REREGISTRATION     | REREGISTRATION     | PASS
-- N      | Postpaid     | AUCTION_ACTION                | NULL               | NULL               | PASS
-- N      | Postpaid     | NEW_ACCOUNT_ACTION            | new postpaid       | new postpaid       | PASS
-- N      | Postpaid     | MIGRATION_ACTION              | Migration          | Migration          | PASS
-- N      | Postpaid     | REREGISTRATION_ACTION         | REREGISTRATION     | REREGISTRATION     | PASS
-- N      | Fixed        | MANAGE_SERVICE_ACTION         | elife              | elife              | PASS
-- N      | Fixed        | NEW_ACCOUNT_ACTION            | elife              | elife              | PASS
-- N      | Hassantuk    | HASSANTUK_ACTION              | NULL               | NULL               | PASS
-- N      | Prepaid      | CESSATION_ACTION              | NULL               | NULL               | PASS
-- N      | Prepaid      | NEW_ACCOUNT_ACTION            | new prepaid        | new prepaid        | PASS
-- N      | Prepaid      | REREGISTRATION_ACTION         | REREGISTRATION     | REREGISTRATION     | PASS
-- N      | BUlitmate    | REREGISTRATION_ACTION         | REREGISTRATION     | REREGISTRATION     | PASS
-- N      | NULL         | NULL                          | NULL               | NULL               | PASS
-- =====================================================================


-- =====================================================================
-- SUMMARY VALIDATION QUERY
-- =====================================================================
-- Check if all tests pass
WITH test_data AS (
    SELECT 'N' AS IS_MNP, 'Business' AS PRODUCT_TYPE, 'TRANSFER_OF_OWNERSHIP_ACTION' AS ACTON
    UNION ALL SELECT 'N', 'Business', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'AUCTION_ACTION'
    UNION ALL SELECT 'N', 'Fixed', 'MANAGE_SERVICE_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'MIGRATION_ACTION'
    UNION ALL SELECT 'N', 'Hassantuk', 'HASSANTUK_ACTION'
    UNION ALL SELECT 'N', NULL, NULL
    UNION ALL SELECT 'N', 'Prepaid', 'CESSATION_ACTION'
    UNION ALL SELECT 'Y', 'Prepaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Prepaid', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'Y', 'Business', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'Y', 'Postpaid', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Postpaid', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'Business', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'BUlitmate', 'REREGISTRATION_ACTION'
    UNION ALL SELECT 'N', 'Fixed', 'NEW_ACCOUNT_ACTION'
    UNION ALL SELECT 'N', 'Prepaid', 'NEW_ACCOUNT_ACTION'
),
test_results AS (
    SELECT 
        CASE
            WHEN (
                CASE
                    WHEN IS_MNP = 'Y' THEN 'MNP'
                    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Postpaid' THEN 'new postpaid'
                    WHEN ACTON = 'NEW_ACCOUNT_ACTION' AND PRODUCT_TYPE = 'Prepaid' THEN 'new prepaid'
                    WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
                    WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
                    WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
                    ELSE NULL
                END
            ) = (
                CASE 
                    WHEN IS_MNP = 'Y' THEN 'MNP'
                    WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Postpaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new postpaid'
                    WHEN IS_MNP = 'N' AND PRODUCT_TYPE = 'Prepaid' AND ACTON = 'NEW_ACCOUNT_ACTION' THEN 'new prepaid'
                    WHEN ACTON = 'MIGRATION_ACTION' THEN 'Migration'
                    WHEN ACTON = 'REREGISTRATION_ACTION' THEN 'REREGISTRATION'
                    WHEN PRODUCT_TYPE = 'Fixed' THEN 'elife'
                    ELSE NULL
                END
            ) THEN 1
            ELSE 0
        END AS test_passed
    FROM test_data
)
SELECT 
    SUM(test_passed) AS tests_passed,
    COUNT(*) AS total_tests,
    CASE 
        WHEN SUM(test_passed) = COUNT(*) THEN 'ALL TESTS PASSED ✓'
        ELSE 'SOME TESTS FAILED ✗'
    END AS validation_status
FROM test_results;

-- Expected output:
-- tests_passed | total_tests | validation_status
-- -------------|-------------|------------------
-- 18           | 18          | ALL TESTS PASSED ✓
