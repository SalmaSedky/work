-- =====================================================================
-- CLASSIFICATION ID SETUP - CL_SCM and CL_CV Tables
-- =====================================================================
-- Purpose: Setup classification schema and classification values tables
--          for Portal Transaction Type classifications
-- Tables:
--   - CL_SCM: Classification Schema (defines classification categories)
--   - CL_CV: Classification Values (defines specific values within each category)
-- =====================================================================

-- =====================================================================
-- TABLE: CL_SCM (Classification Schema)
-- =====================================================================
-- Defines classification categories/schemas
-- Each schema represents a type of classification (e.g., Portal Transaction Type)

CREATE TABLE IF NOT EXISTS dev_sor.ADMIN.CL_SCM (
    CL_SCM_ID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CL_SCM_NM VARCHAR(255) NOT NULL UNIQUE,
    CL_SCM_DESC VARCHAR(1000),
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CREATED_BY VARCHAR(100),
    UPDATED_DATE TIMESTAMP,
    UPDATED_BY VARCHAR(100),
    ACTIVE_FLAG CHAR(1) DEFAULT 'Y'
);

-- =====================================================================
-- TABLE: CL_CV (Classification Values)
-- =====================================================================
-- Defines specific classification values within each schema
-- Links to CL_SCM via CL_SCM_ID

CREATE TABLE IF NOT EXISTS dev_sor.ADMIN.CL_CV (
    CL_CV_ID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CL_SCM_ID BIGINT NOT NULL,
    CL_NM VARCHAR(255) NOT NULL,
    CL_DESC VARCHAR(1000),
    CL_CODE VARCHAR(50),
    DISPLAY_ORDER INT,
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CREATED_BY VARCHAR(100),
    UPDATED_DATE TIMESTAMP,
    UPDATED_BY VARCHAR(100),
    ACTIVE_FLAG CHAR(1) DEFAULT 'Y',
    CONSTRAINT FK_CL_CV_CL_SCM FOREIGN KEY (CL_SCM_ID) REFERENCES dev_sor.ADMIN.CL_SCM(CL_SCM_ID),
    CONSTRAINT UQ_CL_CV_SCHEMA_NAME UNIQUE (CL_SCM_ID, CL_NM)
);

-- =====================================================================
-- DATA INSERTION - CL_SCM (Classification Schema)
-- =====================================================================

-- Insert the Portal Transaction Type classification schema
INSERT INTO dev_sor.ADMIN.CL_SCM (CL_SCM_NM, CL_SCM_DESC, CREATED_BY, ACTIVE_FLAG)
VALUES (
    'Portal Transaction Type',
    'Classification schema for portal transaction types including MNP, new accounts, migrations, and other transaction categories',
    'SYSTEM',
    'Y'
);

-- Get the CL_SCM_ID for Portal Transaction Type (will be 1 if first entry)
-- In practice, you can query: SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'

-- =====================================================================
-- DATA INSERTION - CL_CV (Classification Values)
-- =====================================================================

-- Insert all Portal Transaction Type classification values
-- Note: CL_SCM_ID will be dynamically obtained, but assuming it's 1 for this example

-- Classification 1: Business Ultimate
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'Business Ultimate',
    'Business Ultimate product type for BUlitmate and Business product categories',
    'BUS_ULT',
    1,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'Business Ultimate'
);

-- Classification 2: MNP (Mobile Number Portability)
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'MNP',
    'Mobile Number Portability - customer porting number from another provider',
    'MNP',
    2,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'MNP'
);

-- Classification 3: New Prepaid
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'New Prepaid',
    'New prepaid account activation without number portability',
    'NEW_PREPAID',
    3,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'New Prepaid'
);

-- Classification 4: New Postpaid
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'New Postpaid',
    'New postpaid account activation without number portability',
    'NEW_POSTPAID',
    4,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'New Postpaid'
);

-- Classification 5: Migration
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'Migration',
    'Customer migrating between plans or services',
    'MIGRATION',
    5,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'Migration'
);

-- Classification 6: Portal Reregistration
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'Portal Reregistration',
    'Re-registration of existing customer or SIM through portal',
    'PORTAL_REREG',
    6,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'Portal Reregistration'
);

-- Classification 7: Elife
INSERT INTO dev_sor.ADMIN.CL_CV (CL_SCM_ID, CL_NM, CL_DESC, CL_CODE, DISPLAY_ORDER, CREATED_BY, ACTIVE_FLAG)
SELECT 
    (SELECT CL_SCM_ID FROM dev_sor.ADMIN.CL_SCM WHERE CL_SCM_NM = 'Portal Transaction Type'),
    'Elife',
    'Fixed broadband/internet services (eLife product line)',
    'ELIFE',
    7,
    'SYSTEM',
    'Y'
WHERE NOT EXISTS (
    SELECT 1 FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = 'Portal Transaction Type' AND cv.CL_NM = 'Elife'
);

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Verify CL_SCM entries
SELECT 
    CL_SCM_ID,
    CL_SCM_NM,
    CL_SCM_DESC,
    ACTIVE_FLAG,
    CREATED_DATE
FROM dev_sor.ADMIN.CL_SCM
ORDER BY CL_SCM_ID;

-- Verify CL_CV entries with schema name
SELECT 
    cv.CL_CV_ID,
    scm.CL_SCM_NM,
    cv.CL_NM,
    cv.CL_DESC,
    cv.CL_CODE,
    cv.DISPLAY_ORDER,
    cv.ACTIVE_FLAG
FROM dev_sor.ADMIN.CL_CV cv
JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
WHERE scm.CL_SCM_NM = 'Portal Transaction Type'
ORDER BY cv.DISPLAY_ORDER;

-- =====================================================================
-- EXPECTED OUTPUT FROM VERIFICATION
-- =====================================================================
/*
CL_CV_ID | CL_SCM_NM                  | CL_NM                  | CL_CODE        | DISPLAY_ORDER
---------|----------------------------|------------------------|----------------|---------------
1        | Portal Transaction Type    | Business Ultimate      | BUS_ULT        | 1
2        | Portal Transaction Type    | MNP                    | MNP            | 2
3        | Portal Transaction Type    | New Prepaid            | NEW_PREPAID    | 3
4        | Portal Transaction Type    | New Postpaid           | NEW_POSTPAID   | 4
5        | Portal Transaction Type    | Migration              | MIGRATION      | 5
6        | Portal Transaction Type    | Portal Reregistration  | PORTAL_REREG   | 6
7        | Portal Transaction Type    | Elife                  | ELIFE          | 7
*/

-- =====================================================================
-- HELPER FUNCTION: Get Classification ID by Name
-- =====================================================================
-- This function can be used to easily retrieve CL_CV_ID by classification name

CREATE OR REPLACE FUNCTION dev_sor.ADMIN.GET_CLASSIFICATION_ID(
    p_schema_name VARCHAR(255),
    p_classification_name VARCHAR(255)
)
RETURNS BIGINT
LANGUAGE SQL
AS
$$
    SELECT cv.CL_CV_ID
    FROM dev_sor.ADMIN.CL_CV cv
    JOIN dev_sor.ADMIN.CL_SCM scm ON cv.CL_SCM_ID = scm.CL_SCM_ID
    WHERE scm.CL_SCM_NM = p_schema_name
      AND cv.CL_NM = p_classification_name
      AND cv.ACTIVE_FLAG = 'Y'
$$;

-- Example usage:
-- SELECT dev_sor.ADMIN.GET_CLASSIFICATION_ID('Portal Transaction Type', 'MNP');

-- =====================================================================
-- MAINTENANCE NOTES
-- =====================================================================
/*
To add a new classification value:
1. INSERT into CL_CV with appropriate CL_SCM_ID
2. Assign a unique CL_NM
3. Set DISPLAY_ORDER for proper ordering
4. Add corresponding CASE condition in queries

To modify a classification:
1. UPDATE CL_CV SET fields as needed
2. Update UPDATED_DATE and UPDATED_BY
3. Review all queries using this classification

To disable a classification:
1. UPDATE CL_CV SET ACTIVE_FLAG = 'N' WHERE CL_CV_ID = ?
2. Queries should filter on ACTIVE_FLAG = 'Y'
*/
