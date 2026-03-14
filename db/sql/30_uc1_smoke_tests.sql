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

PRINT '=== ReviewRun reliability checks ===';
SELECT
    COUNT(*) AS total_runs,
    SUM(CASE WHEN content_hash IS NULL THEN 1 ELSE 0 END) AS runs_missing_content_hash,
    SUM(CASE WHEN baseline_run_id IS NULL THEN 1 ELSE 0 END) AS runs_missing_baseline_run_id
FROM uc1.ReviewRun;

;WITH ordered_runs AS (
    SELECT
        rr.run_id,
        rr.project_number,
        ROW_NUMBER() OVER (PARTITION BY rr.project_number ORDER BY rr.run_ts_utc, rr.run_id) AS run_ordinal
    FROM uc1.ReviewRun rr
)
SELECT
    COUNT(*) AS first_runs_with_non_self_baseline
FROM ordered_runs o
JOIN uc1.ReviewRun rr ON rr.run_id = o.run_id
WHERE o.run_ordinal = 1
  AND rr.baseline_run_id <> rr.run_id;

PRINT '=== Citation coverage checks ===';
SELECT
    COUNT(*) AS total_citations,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(c.policy_reference, ''))), '') IS NULL THEN 1 ELSE 0 END) AS citations_missing_policy_reference
FROM uc1.Citation c;

PRINT '=== Doc title distribution (monitor concentration) ===';
SELECT TOP 25
    c.source_type,
    c.doc_title,
    COUNT(*) AS citation_count,
    COUNT(DISTINCT f.project_number) AS project_count
FROM uc1.Citation c
JOIN uc1.Flag f ON f.flag_id = c.flag_id
GROUP BY c.source_type, c.doc_title
ORDER BY citation_count DESC, c.doc_title;
