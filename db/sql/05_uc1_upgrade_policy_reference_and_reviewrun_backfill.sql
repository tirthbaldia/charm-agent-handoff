/* UC1 in-place upgrade:
   - Citation: move to policy_reference and remove legacy citation columns
   - ReviewRun: backfill missing content_hash and baseline_run_id
*/

SET XACT_ABORT ON;
GO

IF OBJECT_ID('uc1.Citation', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('uc1.Citation', 'policy_reference') IS NULL
        ALTER TABLE uc1.Citation ADD policy_reference nvarchar(255) NULL;

    DECLARE @has_requirement bit = CASE WHEN COL_LENGTH('uc1.Citation', 'requirement_id') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @has_clause bit = CASE WHEN COL_LENGTH('uc1.Citation', 'clause_id') IS NOT NULL THEN 1 ELSE 0 END;

    IF @has_requirement = 1 OR @has_clause = 1
    BEGIN
        DECLARE @req_expr nvarchar(200) = CASE
            WHEN @has_requirement = 1 THEN N'NULLIF(LTRIM(RTRIM(COALESCE(c.requirement_id, ''''))), '''')'
            ELSE N'NULL'
        END;
        DECLARE @clause_expr nvarchar(200) = CASE
            WHEN @has_clause = 1 THEN N'NULLIF(LTRIM(RTRIM(COALESCE(c.clause_id, ''''))), '''')'
            ELSE N'NULL'
        END;
        DECLARE @sql nvarchar(max) = N'
            UPDATE c
            SET policy_reference = NULLIF(LTRIM(RTRIM(
                CASE
                    WHEN c.source_type = ''internal_rubric'' THEN COALESCE(' + @req_expr + N', ' + @clause_expr + N')
                    WHEN c.source_type = ''external'' THEN COALESCE(' + @clause_expr + N', ' + @req_expr + N')
                    ELSE COALESCE(' + @req_expr + N', ' + @clause_expr + N')
                END
            )), '''')
            FROM uc1.Citation c
            WHERE NULLIF(LTRIM(RTRIM(COALESCE(c.policy_reference, ''''))), '''') IS NULL;';

        EXEC sys.sp_executesql @sql;
    END;

    IF COL_LENGTH('uc1.Citation', 'source_url') IS NOT NULL
        ALTER TABLE uc1.Citation DROP COLUMN source_url;

    IF COL_LENGTH('uc1.Citation', 'requirement_id') IS NOT NULL
        ALTER TABLE uc1.Citation DROP COLUMN requirement_id;

    IF COL_LENGTH('uc1.Citation', 'clause_id') IS NOT NULL
        ALTER TABLE uc1.Citation DROP COLUMN clause_id;
END;
GO

IF OBJECT_ID('uc1.ReviewRun', 'U') IS NOT NULL
BEGIN
    UPDATE rr
    SET rr.content_hash = rr.run_signature_hash
    FROM uc1.ReviewRun rr
    WHERE rr.content_hash IS NULL
      AND rr.run_signature_hash IS NOT NULL;

    ;WITH ordered_runs AS (
        SELECT
            rr.run_id,
            rr.project_number,
            LAG(rr.run_id) OVER (
                PARTITION BY rr.project_number
                ORDER BY rr.run_ts_utc, rr.run_id
            ) AS previous_run_id
        FROM uc1.ReviewRun rr
    )
    UPDATE rr
    SET rr.baseline_run_id = COALESCE(o.previous_run_id, rr.run_id)
    FROM uc1.ReviewRun rr
    JOIN ordered_runs o ON o.run_id = rr.run_id
    WHERE rr.baseline_run_id IS NULL;
END;
GO

SELECT
    COUNT(*) AS total_citations,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(policy_reference, ''))), '') IS NULL THEN 1 ELSE 0 END) AS citations_missing_policy_reference
FROM uc1.Citation;

SELECT
    COUNT(*) AS total_runs,
    SUM(CASE WHEN content_hash IS NULL THEN 1 ELSE 0 END) AS runs_missing_content_hash,
    SUM(CASE WHEN baseline_run_id IS NULL THEN 1 ELSE 0 END) AS runs_missing_baseline
FROM uc1.ReviewRun;
GO
