/* UC1 post-deploy smoke tests */
SET NOCOUNT ON;

PRINT '=== Object inventory ===';
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id=t.schema_id
WHERE s.name='uc1'
ORDER BY t.name;

SELECT s.name AS schema_name, v.name AS view_name
FROM sys.views v
JOIN sys.schemas s ON s.schema_id=v.schema_id
WHERE s.name='uc1'
ORDER BY v.name;

SELECT s.name AS schema_name, p.name AS proc_name
FROM sys.procedures p
JOIN sys.schemas s ON s.schema_id=p.schema_id
WHERE s.name='uc1'
ORDER BY p.name;

PRINT '=== Stored procedure execution check ===';
EXEC uc1.GetReviews @project_number=NULL, @top_n=5;

PRINT '=== Dashboard view shape checks ===';
SELECT TOP 5 * FROM uc1.vw_ProposalSummary ORDER BY run_ts_utc DESC;
SELECT TOP 5 * FROM uc1.vw_ProjectRiskMatrix ORDER BY run_ts_utc DESC;
SELECT TOP 5 * FROM uc1.vw_FlagList ORDER BY run_ts_utc DESC;
SELECT TOP 5 * FROM uc1.vw_DashboardRiskTypeSeverity ORDER BY run_ts_utc DESC;
SELECT TOP 12 * FROM uc1.vw_DashboardMonthlyTrend ORDER BY month_start_utc DESC;
