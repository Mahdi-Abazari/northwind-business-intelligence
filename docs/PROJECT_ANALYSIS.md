# Technical analysis of the Northwind BI project

This document maps the submitted work to reviewable artifacts and separates observed results from modeling assumptions. The project was completed by a three-person group; the original report describes shared participation across phases.

## Scope and architecture

The work follows Northwind's order-to-delivery business flow. The source entities include customers, orders and order details, products and categories, employees, suppliers, shippers, and geographic tables. Phase 0 defines the business model and KPI questions. Phase 1 profiles and cleans 13 CSV tables in Python. Phase 2 prepares an operational workbook with validation, Power Query, data modeling, and VBA automation. Phase 3 implements a transactional prototype in Access. Phase 4 develops MySQL schema and analytical SQL. Phase 5 builds a star-style analytical model and Power BI reports. Phase 6 interprets the dashboards for management. Phase 7 presents the work through a local WordPress site.

The Power BI file contains seven report pages: Company Overview, Profitability & Sales Quality, Product & Employee Deep Dive, Customer Analysis, Business Risk & Dependency, Logistics & Shipping Analysis, and Pricing & Discount Strategy. The model described in the report centers on `FactSales` with customer, employee, product, shipper, and date dimensions.

## Reviewable implementation

| Component | Evidence in this repository | What it demonstrates |
| --- | --- | --- |
| Python preparation | [`data_preprocessing.ipynb`](../Phase_1_DataPreprocessing_python/data_preprocessing.ipynb) | Missing-value handling, duplicate checks, type corrections, and feature engineering |
| Excel operations | [`operational_analysis.xlsm`](../Phase_2_Operational_Data_preparation_Excel/operational_analysis.xlsm) | Workbook model, Power Query connections, validation, and VBA |
| SQL engineering | [`Phase_4_Data_Engineering_SQL/`](../Phase_4_Data_Engineering_SQL/) | DDL, analytical joins and aggregation, pricing analysis, indexing, stress testing, and views |
| BI model | [`Phase_5_Group1.pbix`](../Phase_5_Strategic_Business_Intelligence_PowerBI/Phase_5_Group1.pbix) | Seven report pages and saved semantic model |
| Full narrative | [`Project_Report_Public.pdf`](Project_Report_Public.pdf) | Design rationale, dashboard interpretation, and WordPress phase |

The public Python notebook has its execution outputs cleared, so it contains code and explanation without embedded raw rows. The public Excel workbook preserves its sheets and VBA while removing an absolute local path from workbook metadata. Neither source original was modified.

## Selected evidence and interpretation

- The executive dashboard displays about **$1.27M in sales** and **$379.74K in modeled profit** for the supplied Northwind sample.
- The profitability view displays a **5.62% average discount** and **4.27% late-delivery rate** in its saved state. Filters can change a Power BI page's visible figures.
- Profit is calculated with an assumed, constant **30% margin** (`CostAmount = SalesAmount × 0.7`). A discount-to-margin Pearson correlation is undefined when the margin has zero variance. Displaying `N/A` is an explicit analytical choice, not a missing KPI.
- The report examines customer concentration, sales quality, employee workload, shipping performance, discount strategy, and product mix. Its recommendations are based on a sample business scenario and should not be read as findings about a real company.

## Constraints and reproducibility

The local Access database, full SQL dump, raw CSV files, and WordPress backup are intentionally excluded. The SQL scripts include operations that create or change schema objects, so they should be reviewed and executed in a disposable Northwind environment. The Power BI file can be inspected as a saved artifact; a data refresh requires reconnecting a local Northwind source. The Excel workbook similarly requires the original inputs for refresh. The complete report is in Persian; its public edition replaces only the cover to omit student numbers.

The original LaTeX report source depends on 54 figures stored at absolute paths outside this folder, so it is not presented as a reproducible source build. The repository presents the finished report and the surviving source artifacts without implying that every local environment can be recreated from GitHub alone.
