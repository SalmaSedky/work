# Table Mapping: WINPROD Source to DWH Staging Tables

## Overview
This document maps the original WINPROD source tables to their corresponding DWH staging tables (STG) used in the Enhanced Query 2 implementation.

---

## Table Mapping Reference

| WINPROD Source Table | DWH Staging Table | Description |
|---------------------|-------------------|-------------|
| `WINPROD.ORDHDR` | `DEV_STG..STG_WC_ORDHDR_VIEW1` | Order Header - WH to Shop deliveries |
| `WINPROD.ORDDTL` | `DEV_STG..STG_WC_ORDDTL_VW` | Order Details - Delivery line items |
| `WINPROD.MATERIAL` | `DEV_STG..STG_WC_MATERIAL_VW` | Material Master - Item definitions |
| `WINPROD.OFFICE` | `DEV_STG..STG_WC_OFFICE_VW` | Office/Store Master |
| `WINPROD.SUPPLIER` | `DEV_STG..STG_WC_SUPPLIER_VW` | Supplier/Warehouse Master |
| `WINPROD.DBOD` | `DEV_STG..STG_WC_DBOD_VW` | Delivery Note Reference |
| `WINPROD.CMSHDR` | `DEV_STG..STG_WC_CMSHDR_VIEW1` | CMS Header - Shop transfers |
| `WINPROD.CMSDTL` | `DEV_STG..STG_WC_CMSDTL_VIEW1` | CMS Details - Transfer line items |
| `WINPROD.CLIENT` | `DEV_STG..STG_WC_CLIENT_VIEW1` | Client/Warehouse Master (returns) |
| `WINPROD.VOUHDR` | `DEV_STG..STG_WC_VOUHDR_VIEW1` | Voucher Header - Sales transactions |
| `WINPROD.VOUDTL` | `DEV_STG..STG_WC_VOUDTL_VIEW1` | Voucher Details - Sales line items |
| `WINPROD.WAREGROUP` | `DEV_STG..STG_WC_WAREGROUP_VIEW1` | Warehouse Group |
| `WINPROD.MATGROUP` | `DEV_STG..STG_WC_MATGROUP_VIEW1` | Material Group |
| `WINPROD.STOCK` | `DEV_STG..STG_WC_STOCK_VW` | Stock/Sub-inventory |
| `WINPROD.MATUNIT` | `DEV_STG..STG_WC_MATUNIT_VIEW1` | Material Unit of Measure |
| `WINPROD.VOU2FLEXFIELD` | `DEV_STG..STG_WC_VOU2FLEXFIELD_VIEW1` | Voucher Flex Fields (Sub Request ID) |
| `WINPROD.MATMOVE` | `DEV_STG..STG_WC_MATMOVE_VIEW1` | Material Movement - Inventory adjustments |
| `WINPROD.MATMOVETYPE` | `DEV_STG..STG_WC_MATMOVETYPE_VW` | Material Movement Type |

---

## Detailed Mapping by Transaction Type

### 1. WH TO SHOP Transactions

**Source Query Tables:**
```sql
FROM WINPROD.ORDHDR OH
INNER JOIN WINPROD.ORDDTL OD ON OH.ORDiD = OD.ORDID
INNER JOIN WINPROD.MATERIAL M ON OD.MATNO = M.MATNO
INNER JOIN WINPROD.OFFICE O ON OD.TREEID = O.TREEID
INNER JOIN WINPROD.SUPPLIER S ON OD.SUPID = S.GID
LEFT OUTER JOIN (SELECT REFNO, DELNOTENO FROM WINPROD.DBOD) D ON D.REFNO = OH.OrdID
```

**DWH Staging Tables:**
```sql
FROM DEV_STG..STG_WC_ORDHDR_VIEW1 OH
INNER JOIN DEV_STG..STG_WC_ORDDTL_VW OD ON OH.ORDiD = OD.ORDID
INNER JOIN DEV_STG..STG_WC_MATERIAL_VW M ON OD.MATNO = M.MATNO
INNER JOIN DEV_STG..STG_WC_OFFICE_VW O ON OD.TREEID = O.TREEID
INNER JOIN DEV_STG..STG_WC_SUPPLIER_VW S ON OD.SUPID = S.GID
LEFT OUTER JOIN (SELECT REFNO, DELNOTENO FROM DEV_STG..STG_WC_DBOD_VW) D ON D.REFNO = OH.OrdID
```

**Mapping:**
- `WINPROD.ORDHDR` → `DEV_STG..STG_WC_ORDHDR_VIEW1`
- `WINPROD.ORDDTL` → `DEV_STG..STG_WC_ORDDTL_VW`
- `WINPROD.MATERIAL` → `DEV_STG..STG_WC_MATERIAL_VW`
- `WINPROD.OFFICE` → `DEV_STG..STG_WC_OFFICE_VW`
- `WINPROD.SUPPLIER` → `DEV_STG..STG_WC_SUPPLIER_VW`
- `WINPROD.DBOD` → `DEV_STG..STG_WC_DBOD_VW`

---

### 2. SHOP TO WH Transactions

**Source Query Tables:**
```sql
FROM WINPROD.CMSHDR HDR
INNER JOIN WINPROD.CMSDTL DTL ON HDR.GID = DTL.CMSID
INNER JOIN WINPROD.MATERIAL M ON DTL.MATNO = M.MATNO
INNER JOIN WINPROD.OFFICE O ON DTL.TREEID = O.TREEID
INNER JOIN WINPROD.CLIENT CLNT ON DTL.CLIENTID = CLNT.GID
```

**DWH Staging Tables:**
```sql
FROM DEV_STG..STG_WC_CMSHDR_VIEW1 HDR
INNER JOIN DEV_STG..STG_WC_CMSDTL_VIEW1 DTL ON HDR.GID = DTL.CMSID
INNER JOIN DEV_STG..STG_WC_MATERIAL_VW M ON DTL.MATNO = M.MATNO
INNER JOIN DEV_STG..STG_WC_OFFICE_VW O ON DTL.TREEID = O.TREEID
INNER JOIN DEV_STG..STG_WC_CLIENT_VIEW1 CLNT ON DTL.CLIENTID = CLNT.GID
```

**Mapping:**
- `WINPROD.CMSHDR` → `DEV_STG..STG_WC_CMSHDR_VIEW1`
- `WINPROD.CMSDTL` → `DEV_STG..STG_WC_CMSDTL_VIEW1`
- `WINPROD.MATERIAL` → `DEV_STG..STG_WC_MATERIAL_VW`
- `WINPROD.OFFICE` → `DEV_STG..STG_WC_OFFICE_VW`
- `WINPROD.CLIENT` → `DEV_STG..STG_WC_CLIENT_VIEW1`

---

### 3. SHOP TO SHOP Transactions

**Source Query Tables:**
```sql
FROM WINPROD.CMSHDR HDR
INNER JOIN WINPROD.CMSDTL DTL ON HDR.GID = DTL.CMSID
INNER JOIN WINPROD.MATERIAL M ON DTL.MATNO = M.MATNO
INNER JOIN WINPROD.OFFICE O ON DTL.TREEID = O.TREEID
INNER JOIN WINPROD.OFFICE OD ON DTL.DSTTREEID = OD.TREEID
```

**DWH Staging Tables:**
```sql
FROM DEV_STG..STG_WC_CMSHDR_VIEW1 HDR
INNER JOIN DEV_STG..STG_WC_CMSDTL_VIEW1 DTL ON HDR.GID = DTL.CMSID
INNER JOIN DEV_STG..STG_WC_MATERIAL_VW M ON DTL.MATNO = M.MATNO
INNER JOIN DEV_STG..STG_WC_OFFICE_VW O ON DTL.TREEID = O.TREEID
INNER JOIN DEV_STG..STG_WC_OFFICE_VW OD ON DTL.DSTTREEID = OD.TREEID
```

**Mapping:**
- `WINPROD.CMSHDR` → `DEV_STG..STG_WC_CMSHDR_VIEW1`
- `WINPROD.CMSDTL` → `DEV_STG..STG_WC_CMSDTL_VIEW1`
- `WINPROD.MATERIAL` → `DEV_STG..STG_WC_MATERIAL_VW`
- `WINPROD.OFFICE` → `DEV_STG..STG_WC_OFFICE_VW` (used twice for originating and receiving stores)

---

### 4. SALES/RETURN/CANCEL Transactions

**Source Query Tables:**
```sql
FROM WINPROD.VOUHDR VH
INNER JOIN WINPROD.VOUDTL VD ON VH.JOUID = VD.JOUID AND VH.TREEID = VD.TREEID
INNER JOIN WINPROD.OFFICE O ON O.TREEID = VD.TREEID
INNER JOIN WINPROD.MATERIAL M ON M.GID = VD.MATID
INNER JOIN WINPROD.WAREGROUP WG ON WG.GID = VD.WGID
INNER JOIN WINPROD.MATGROUP MG ON MG.GID = M.MGID
INNER JOIN WINPROD.STOCK S ON S.GID = VD.STOCKID
INNER JOIN WINPROD.MATUNIT MU ON MU.GID = M.UNITID
LEFT OUTER JOIN WINPROD.VOU2FLEXFIELD V2FF ON V2FF.JOUID = VD.JOUID AND V2FF.DTLID = VD.DTLID
```

**DWH Staging Tables:**
```sql
FROM DEV_STG..STG_WC_VOUHDR_VIEW1 VH
INNER JOIN DEV_STG..STG_WC_VOUDTL_VIEW1 VD ON VH.JOUID = VD.JOUID AND VH.TREEID = VD.TREEID
INNER JOIN DEV_STG..STG_WC_OFFICE_VW O ON O.TREEID = VD.TREEID
INNER JOIN DEV_STG..STG_WC_MATERIAL_VW M ON M.GID = VD.MATID
INNER JOIN DEV_STG..STG_WC_WAREGROUP_VIEW1 WG ON WG.GID = VD.WGID
INNER JOIN DEV_STG..STG_WC_MATGROUP_VIEW1 MG ON MG.GID = M.MGID
INNER JOIN DEV_STG..STG_WC_STOCK_VW S ON S.GID = VD.STOCKID
INNER JOIN DEV_STG..STG_WC_MATUNIT_VIEW1 MU ON MU.GID = M.UNITID
LEFT OUTER JOIN DEV_STG..STG_WC_VOU2FLEXFIELD_VIEW1 V2FF ON V2FF.JOUID = VD.JOUID AND V2FF.DTLID = VD.DTLID
```

**Mapping:**
- `WINPROD.VOUHDR` → `DEV_STG..STG_WC_VOUHDR_VIEW1`
- `WINPROD.VOUDTL` → `DEV_STG..STG_WC_VOUDTL_VIEW1`
- `WINPROD.OFFICE` → `DEV_STG..STG_WC_OFFICE_VW`
- `WINPROD.MATERIAL` → `DEV_STG..STG_WC_MATERIAL_VW`
- `WINPROD.WAREGROUP` → `DEV_STG..STG_WC_WAREGROUP_VIEW1`
- `WINPROD.MATGROUP` → `DEV_STG..STG_WC_MATGROUP_VIEW1`
- `WINPROD.STOCK` → `DEV_STG..STG_WC_STOCK_VW`
- `WINPROD.MATUNIT` → `DEV_STG..STG_WC_MATUNIT_VIEW1`
- `WINPROD.VOU2FLEXFIELD` → `DEV_STG..STG_WC_VOU2FLEXFIELD_VIEW1`

---

### 5. STOCK TAKE Transactions

**Source Query Tables:**
```sql
FROM WINPROD.MATMOVE MV
INNER JOIN WINPROD.MATMOVETYPE MVT ON MV.MVTYPEID = MVT.GID
INNER JOIN WINPROD.MATERIAL M ON MV.MATID = M.GID
INNER JOIN WINPROD.OFFICE O ON MV.TREEID = O.TREEID
INNER JOIN WINPROD.MATGROUP MG ON MG.GID = M.MGID
INNER JOIN WINPROD.STOCK S ON S.GID = MV.STOCKID
INNER JOIN WINPROD.MATUNIT MU ON MU.GID = M.UNITID
```

**DWH Staging Tables:**
```sql
FROM DEV_STG..STG_WC_MATMOVE_VIEW1 MV
INNER JOIN DEV_STG..STG_WC_MATMOVETYPE_VW MVT ON MV.MVTYPEID = MVT.GID
INNER JOIN DEV_STG..STG_WC_MATERIAL_VW M ON MV.MATID = M.GID
INNER JOIN DEV_STG..STG_WC_OFFICE_VW O ON MV.TREEID = O.TREEID
INNER JOIN DEV_STG..STG_WC_MATGROUP_VIEW1 MG ON MG.GID = M.MGID
INNER JOIN DEV_STG..STG_WC_STOCK_VW S ON S.GID = MV.STOCKID
INNER JOIN DEV_STG..STG_WC_MATUNIT_VIEW1 MU ON MU.GID = M.UNITID
```

**Mapping:**
- `WINPROD.MATMOVE` → `DEV_STG..STG_WC_MATMOVE_VIEW1`
- `WINPROD.MATMOVETYPE` → `DEV_STG..STG_WC_MATMOVETYPE_VW`
- `WINPROD.MATERIAL` → `DEV_STG..STG_WC_MATERIAL_VW`
- `WINPROD.OFFICE` → `DEV_STG..STG_WC_OFFICE_VW`
- `WINPROD.MATGROUP` → `DEV_STG..STG_WC_MATGROUP_VIEW1`
- `WINPROD.STOCK` → `DEV_STG..STG_WC_STOCK_VW`
- `WINPROD.MATUNIT` → `DEV_STG..STG_WC_MATUNIT_VIEW1`

---

## Naming Convention Analysis

### Pattern Recognition

| Suffix Pattern | Count | Purpose |
|---------------|-------|---------|
| `_VIEW1` | 10 tables | Views with version suffix (header/detail tables) |
| `_VW` | 8 tables | Standard views (master/lookup tables) |

**Tables with `_VIEW1` suffix:**
- STG_WC_ORDHDR_VIEW1
- STG_WC_CMSHDR_VIEW1
- STG_WC_CMSDTL_VIEW1
- STG_WC_VOUHDR_VIEW1
- STG_WC_VOUDTL_VIEW1
- STG_WC_CLIENT_VIEW1
- STG_WC_WAREGROUP_VIEW1
- STG_WC_MATGROUP_VIEW1
- STG_WC_MATUNIT_VIEW1
- STG_WC_VOU2FLEXFIELD_VIEW1
- STG_WC_MATMOVE_VIEW1

**Tables with `_VW` suffix:**
- STG_WC_ORDDTL_VW
- STG_WC_MATERIAL_VW
- STG_WC_OFFICE_VW
- STG_WC_SUPPLIER_VW
- STG_WC_DBOD_VW
- STG_WC_STOCK_VW
- STG_WC_MATMOVETYPE_VW

**Naming Convention:**
```
DEV_STG..STG_WC_<TABLE_NAME>_<VIEW|VW>
```

Where:
- `DEV_STG` = Database/Schema for staging
- `STG` = Staging prefix
- `WC` = Source system identifier (WinCash/WINPROD)
- `<TABLE_NAME>` = Original table name in UPPERCASE
- `_VIEW1` or `_VW` = View designation

---

## Key Differences: Source vs Staging

### 1. Date Handling

**Source (Oracle):**
```sql
TRUNC(VH.POSDAT) BETWEEN TO_DATE('2025-11-01', 'YYYY-MM-DD') AND TO_DATE('2025-11-30', 'YYYY-MM-DD')
```

**Staging (Snowflake/similar):**
```sql
VH.POSDAT :: DATE BETWEEN '2025-11-01' AND '2025-11-30'
```

### 2. Type Casting

**Source:**
```sql
TO_CHAR(OH.OrdID)
```

**Staging:**
```sql
OH.OrdID :: VARCHAR(50)
```

### 3. Schema Qualification

**Source:**
```sql
WINPROD.ORDHDR
```

**Staging:**
```sql
DEV_STG..STG_WC_ORDHDR_VIEW1
```

### 4. Date Functions

**Source:**
```sql
TRUNC(VH.POSDAT) AS TRANSACTION_DATE
```

**Staging:**
```sql
DATE(VH.POSDAT) AS TRANSACTION_DATE
```

---

## Quick Reference Table

### Master Data Tables

| Business Entity | Source Table | Staging Table |
|----------------|--------------|---------------|
| Items/Materials | WINPROD.MATERIAL | DEV_STG..STG_WC_MATERIAL_VW |
| Stores/Offices | WINPROD.OFFICE | DEV_STG..STG_WC_OFFICE_VW |
| Warehouses (Suppliers) | WINPROD.SUPPLIER | DEV_STG..STG_WC_SUPPLIER_VW |
| Warehouses (Clients) | WINPROD.CLIENT | DEV_STG..STG_WC_CLIENT_VIEW1 |
| Material Groups | WINPROD.MATGROUP | DEV_STG..STG_WC_MATGROUP_VIEW1 |
| Warehouse Groups | WINPROD.WAREGROUP | DEV_STG..STG_WC_WAREGROUP_VIEW1 |
| Stock/Sub-inventory | WINPROD.STOCK | DEV_STG..STG_WC_STOCK_VW |
| Unit of Measure | WINPROD.MATUNIT | DEV_STG..STG_WC_MATUNIT_VIEW1 |

### Transaction Header Tables

| Transaction Type | Source Table | Staging Table |
|-----------------|--------------|---------------|
| WH to Shop Orders | WINPROD.ORDHDR | DEV_STG..STG_WC_ORDHDR_VIEW1 |
| Shop Transfers | WINPROD.CMSHDR | DEV_STG..STG_WC_CMSHDR_VIEW1 |
| Sales/Returns | WINPROD.VOUHDR | DEV_STG..STG_WC_VOUHDR_VIEW1 |
| Inventory Movements | WINPROD.MATMOVE | DEV_STG..STG_WC_MATMOVE_VIEW1 |

### Transaction Detail Tables

| Transaction Type | Source Table | Staging Table |
|-----------------|--------------|---------------|
| WH to Shop Order Lines | WINPROD.ORDDTL | DEV_STG..STG_WC_ORDDTL_VW |
| Shop Transfer Lines | WINPROD.CMSDTL | DEV_STG..STG_WC_CMSDTL_VIEW1 |
| Sales/Return Lines | WINPROD.VOUDTL | DEV_STG..STG_WC_VOUDTL_VIEW1 |

### Reference/Lookup Tables

| Purpose | Source Table | Staging Table |
|---------|--------------|---------------|
| Delivery Notes | WINPROD.DBOD | DEV_STG..STG_WC_DBOD_VW |
| Movement Types | WINPROD.MATMOVETYPE | DEV_STG..STG_WC_MATMOVETYPE_VW |
| Flex Fields | WINPROD.VOU2FLEXFIELD | DEV_STG..STG_WC_VOU2FLEXFIELD_VIEW1 |

---

## Usage Notes

### For ETL Development:
1. Replace `WINPROD.` prefix with `DEV_STG..STG_WC_`
2. Add appropriate suffix (`_VIEW1` or `_VW`) based on patterns above
3. Update date functions from Oracle to Snowflake/target platform syntax
4. Convert `TO_CHAR()` to `:: VARCHAR(50)`
5. Convert `TRUNC()` to `:: DATE` or `DATE()`

### For Query Conversion:
Use the mapping tables above to systematically replace source table references with staging table references while maintaining all join logic and business rules.

### For Enhanced Query 2 with INBOUND/OUTBOUND:
Apply the same table mappings to the Enhanced Query 2 that includes:
- WH TO SHOP_OUTBOUND + WH TO SHOP_INBOUND
- SHOP TO WH_OUTBOUND + SHOP TO WH_INBOUND
- SHOP TO SHOP_OUTBOUND + SHOP TO SHOP_INBOUND

---

## Verification Checklist

When converting queries, verify:

- [ ] All table names converted from `WINPROD.<table>` to `DEV_STG..STG_WC_<table>_<VIEW1|VW>`
- [ ] All date functions converted (TRUNC → DATE or ::DATE)
- [ ] All type casts converted (TO_CHAR → ::VARCHAR)
- [ ] All join conditions maintained
- [ ] All filter conditions preserved
- [ ] Column aliases match expected output
- [ ] Date range parameters updated for target platform

---

## Additional Resources

See also:
- **ENHANCED_QUERY_2_WITH_INBOUND_OUTBOUND.sql** - Source query with WINPROD tables
- **ENHANCED_QUERY_EXPLANATION.md** - Business logic and requirements
- **README.md** - Project overview and usage guide
