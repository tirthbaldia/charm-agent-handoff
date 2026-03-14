/* UC1 procedures (exported from live environment, sanitized packaging) */

IF OBJECT_ID('uc1.AddCitation', 'P') IS NOT NULL DROP PROC uc1.AddCitation;
GO
-- Add one citation line to a flag
CREATE   PROC uc1.AddCitation
 @flag_id        uniqueidentifier,
 @doc_title      nvarchar(255),
 @page           int=NULL,
 @source_type    varchar(16),         -- external|internal_rubric
 @policy_reference nvarchar(255)=NULL,
 @language       char(2)=NULL
AS
BEGIN
  INSERT uc1.Citation(flag_id,doc_title,page,source_type,policy_reference,language)
  VALUES(@flag_id,@doc_title,@page,@source_type,@policy_reference,@language);
END

GO

IF OBJECT_ID('uc1.FinalizeReview', 'P') IS NOT NULL DROP PROC uc1.FinalizeReview;
GO
CREATE   PROC uc1.FinalizeReview
 @project_number nvarchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @current_run_id uniqueidentifier;
    DECLARE @previous_run_id uniqueidentifier;
    DECLARE @current_hash char(64);
    DECLARE @previous_hash char(64);

    SELECT TOP (1) @current_run_id = rr.run_id
    FROM uc1.ReviewRun rr
    WHERE rr.project_number = @project_number
    ORDER BY rr.run_ts_utc DESC, rr.run_id DESC;

    IF @current_run_id IS NULL
        RETURN;

    SELECT TOP (1) @previous_run_id = rr.run_id
    FROM uc1.ReviewRun rr
    WHERE rr.project_number = @project_number
      AND rr.is_final = 1
      AND rr.run_id <> @current_run_id
    ORDER BY rr.run_ts_utc DESC, rr.run_id DESC;

    DECLARE @target_runs TABLE (run_id uniqueidentifier PRIMARY KEY);
    DECLARE @run_hashes TABLE (run_id uniqueidentifier PRIMARY KEY, run_signature_hash char(64) NOT NULL);

    INSERT INTO @target_runs(run_id) VALUES (@current_run_id);
    IF @previous_run_id IS NOT NULL
        INSERT INTO @target_runs(run_id) VALUES (@previous_run_id);

    ;WITH citation_rollup AS (
        SELECT
            f.run_id,
            f.flag_id,
            STRING_AGG(
                CAST(
                    CONCAT(
                        LOWER(LTRIM(RTRIM(COALESCE(c.doc_title,'')))), N'~',
                        COALESCE(CAST(c.page AS nvarchar(20)), N''), N'~',
                        LOWER(LTRIM(RTRIM(COALESCE(c.source_type,'')))), N'~',
                        LOWER(LTRIM(RTRIM(COALESCE(c.policy_reference,'')))), N'~',
                        LOWER(LTRIM(RTRIM(COALESCE(c.language,''))))
                    ) AS nvarchar(max)
                ),
                N'|'
            ) WITHIN GROUP (
                ORDER BY
                    LOWER(LTRIM(RTRIM(COALESCE(c.doc_title,'')))),
                    COALESCE(c.page,-1),
                    LOWER(LTRIM(RTRIM(COALESCE(c.source_type,'')))),
                    LOWER(LTRIM(RTRIM(COALESCE(c.policy_reference,'')))),
                    LOWER(LTRIM(RTRIM(COALESCE(c.language,''))))
            ) AS citation_signature
        FROM uc1.Flag f
        LEFT JOIN uc1.Citation c ON c.flag_id = f.flag_id
        WHERE f.run_id IN (SELECT run_id FROM @target_runs)
        GROUP BY f.run_id, f.flag_id
    ),
    flag_norm AS (
        SELECT
            f.run_id,
            f.flag_id,
            CASE UPPER(f.severity) WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 9 END AS severity_sort,
            LOWER(LTRIM(RTRIM(COALESCE(f.category,'')))) AS category_norm,
            LOWER(LTRIM(RTRIM(COALESCE(f.severity,'')))) AS severity_norm,
            LOWER(LTRIM(RTRIM(COALESCE(f.issue,'')))) AS issue_norm,
            COALESCE(CAST(f.impact AS int), CASE UPPER(f.severity) WHEN 'HIGH' THEN 9 WHEN 'MEDIUM' THEN 6 WHEN 'LOW' THEN 3 ELSE 4 END) AS impact_norm,
            COALESCE(CAST(f.likelihood AS int),
                CASE
                    WHEN COALESCE(f.confidence,0.8) >= 0.95 THEN 10
                    WHEN COALESCE(f.confidence,0.8) >= 0.85 THEN 9
                    WHEN COALESCE(f.confidence,0.8) >= 0.75 THEN 8
                    WHEN COALESCE(f.confidence,0.8) >= 0.65 THEN 7
                    WHEN COALESCE(f.confidence,0.8) >= 0.55 THEN 6
                    WHEN COALESCE(f.confidence,0.8) >= 0.45 THEN 5
                    WHEN COALESCE(f.confidence,0.8) >= 0.35 THEN 4
                    WHEN COALESCE(f.confidence,0.8) >= 0.25 THEN 3
                    WHEN COALESCE(f.confidence,0.8) >= 0.15 THEN 2
                    ELSE 1
                END
            ) AS likelihood_norm,
            COALESCE(cr.citation_signature, N'') AS citation_signature
        FROM uc1.Flag f
        LEFT JOIN citation_rollup cr ON cr.flag_id = f.flag_id AND cr.run_id = f.run_id
        WHERE f.run_id IN (SELECT run_id FROM @target_runs)
    ),
    run_canon AS (
        SELECT
            fn.run_id,
            STRING_AGG(
                CAST(
                    CONCAT(
                        fn.category_norm, N'~',
                        fn.severity_norm, N'~',
                        fn.issue_norm, N'~',
                        CAST(fn.impact_norm AS nvarchar(10)), N'~',
                        CAST(fn.likelihood_norm AS nvarchar(10)), N'~',
                        fn.citation_signature
                    ) AS nvarchar(max)
                ),
                N'||'
            ) WITHIN GROUP (
                ORDER BY fn.severity_sort, fn.category_norm, fn.issue_norm, fn.flag_id
            ) AS canonical_text
        FROM flag_norm fn
        GROUP BY fn.run_id
    )
    INSERT INTO @run_hashes(run_id, run_signature_hash)
    SELECT
        tr.run_id,
        COALESCE(
            LOWER(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(rc.canonical_text AS nvarchar(max))), 2)),
            LOWER(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(N'no_flags' AS nvarchar(max))), 2))
        ) AS run_signature_hash
    FROM @target_runs tr
    LEFT JOIN run_canon rc ON rc.run_id = tr.run_id;

    SELECT @current_hash = rh.run_signature_hash
    FROM @run_hashes rh
    WHERE rh.run_id = @current_run_id;

    SELECT @previous_hash = rh.run_signature_hash
    FROM @run_hashes rh
    WHERE rh.run_id = @previous_run_id;

    IF @current_hash IS NULL
        SET @current_hash = LOWER(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(N'no_flags' AS nvarchar(max))), 2));

    IF @previous_run_id IS NULL
    BEGIN
        UPDATE rr
        SET rr.run_signature_hash = @current_hash,
            rr.content_hash = @current_hash,
            rr.is_drift = 0,
            rr.baseline_run_id = @current_run_id,
            rr.consistency_status = 'Baseline',
            rr.is_final = 1
        FROM uc1.ReviewRun rr
        WHERE rr.run_id = @current_run_id;
    END
    ELSE IF @current_hash = @previous_hash
    BEGIN
        UPDATE rr
        SET rr.run_signature_hash = @current_hash,
            rr.content_hash = @current_hash,
            rr.is_drift = 0,
            rr.baseline_run_id = @previous_run_id,
            rr.consistency_status = 'Match',
            rr.is_final = 1
        FROM uc1.ReviewRun rr
        WHERE rr.run_id = @current_run_id;
    END
    ELSE
    BEGIN
        UPDATE rr
        SET rr.run_signature_hash = @current_hash,
            rr.content_hash = @current_hash,
            rr.is_drift = 1,
            rr.baseline_run_id = @previous_run_id,
            rr.consistency_status = 'Drift',
            rr.is_final = 1
        FROM uc1.ReviewRun rr
        WHERE rr.run_id = @current_run_id;
    END

    UPDATE uc1.Proposal
    SET status = 'Final',
        updated_utc = SYSUTCDATETIME()
    WHERE project_number = @project_number;
END;

GO

IF OBJECT_ID('uc1.GetFlags', 'P') IS NOT NULL DROP PROC uc1.GetFlags;
GO
CREATE   PROC uc1.GetFlags
 @project_number nvarchar(50)
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
      f.flag_id,
      f.project_number,
      f.category,
      f.severity,
      f.issue,
      f.rationale,
      f.confidence,
      f.impact,
      f.likelihood,
      CAST(CASE WHEN f.impact IS NULL OR f.likelihood IS NULL THEN NULL ELSE (f.impact * f.likelihood) / 100.0 END AS decimal(5,3)) AS flag_risk_score,
      f.flag_key,
      rr.run_id,
      rr.run_ts_utc,
      rr.overall_score
  FROM uc1.Flag f
  JOIN uc1.ReviewRun rr ON rr.run_id = f.run_id
  WHERE f.project_number = @project_number
  ORDER BY rr.run_ts_utc DESC, f.severity;
END;

GO

IF OBJECT_ID('uc1.GetReviews', 'P') IS NOT NULL DROP PROC uc1.GetReviews;
GO
CREATE   PROC uc1.GetReviews
    @project_number nvarchar(100)=NULL,
    @top_n int=20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @safe_top int = CASE WHEN @top_n IS NULL OR @top_n < 1 THEN 20 WHEN @top_n > 200 THEN 200 ELSE @top_n END;

    ;WITH base AS (
        SELECT
            rr.run_id,
            rr.project_number,
            p.title,
            p.business_unit,
            p.language,
            rr.run_ts_utc,
            rr.consistency_status,
            rr.is_drift,
            rr.baseline_run_id,
            ROW_NUMBER() OVER (ORDER BY rr.run_ts_utc DESC, rr.run_id DESC) AS rn
        FROM uc1.ReviewRun rr
        JOIN uc1.Proposal p ON p.project_number = rr.project_number
        WHERE @project_number IS NULL OR rr.project_number = @project_number
    ),
    flag_counts AS (
        SELECT
            f.run_id,
            SUM(CASE WHEN f.severity='High' THEN 1 ELSE 0 END) AS high_count,
            SUM(CASE WHEN f.severity='Medium' THEN 1 ELSE 0 END) AS med_count,
            SUM(CASE WHEN f.severity='Low' THEN 1 ELSE 0 END) AS low_count,
            SUM(CASE WHEN f.category='Other' THEN 1 ELSE 0 END) AS other_flags
        FROM uc1.Flag f
        GROUP BY f.run_id
    )
    SELECT
        b.run_id,
        b.project_number,
        b.title,
        b.business_unit,
        b.language,
        b.run_ts_utc,
        CAST(
            CASE
                WHEN COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0) + COALESCE(fc.low_count,0) = 0 THEN 0
                ELSE (1.0 * COALESCE(fc.high_count,0) + 0.7 * COALESCE(fc.med_count,0) + 0.3 * COALESCE(fc.low_count,0))
                     / NULLIF(COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0) + COALESCE(fc.low_count,0), 0)
            END AS decimal(4,3)
        ) AS overall_score,
        COALESCE(fc.high_count,0) AS high_count,
        COALESCE(fc.med_count,0) AS med_count,
        COALESCE(fc.low_count,0) AS low_count,
        COALESCE(fc.other_flags,0) AS other_flags,
        (COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0) + COALESCE(fc.low_count,0)) AS total_flags,
        COALESCE(pm.project_impact, 0) AS project_impact,
        COALESCE(pm.project_likelihood, 0) AS project_likelihood,
        CASE
            WHEN COALESCE(fc.high_count,0) > 0 THEN 'High'
            WHEN COALESCE(fc.med_count,0) > 0 THEN 'Medium'
            WHEN COALESCE(fc.low_count,0) > 0 THEN 'Low'
            ELSE 'None'
        END AS risk_level,
        CASE WHEN (COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0)) > 0 THEN 'Non-compliant' ELSE 'Compliant' END AS compliance_status,
        COALESCE(b.consistency_status, 'Baseline') AS consistency_status,
        COALESCE(b.is_drift, 0) AS is_drift,
        b.baseline_run_id,
        CAST(1 AS bit) AS is_final
    FROM base b
    LEFT JOIN flag_counts fc ON fc.run_id = b.run_id
    LEFT JOIN uc1.vw_ProjectRiskMatrix pm ON pm.run_id = b.run_id
    WHERE b.rn <= @safe_top
    ORDER BY b.run_ts_utc DESC, b.run_id DESC;
END;

GO

IF OBJECT_ID('uc1.UpsertFlag', 'P') IS NOT NULL DROP PROC uc1.UpsertFlag;
GO
CREATE   PROCEDURE uc1.UpsertFlag
    @project_number  nvarchar(100),
    @title           nvarchar(200) = NULL,
    @business_unit   nvarchar(100) = NULL,
    @language        char(2)       = 'EN',
    @run_id          uniqueidentifier,
    @category        varchar(50),
    @severity        varchar(20),
    @issue           nvarchar(400),
    @rationale       nvarchar(1000),
    @flag_key        char(64),
    @confidence      decimal(5,2)  = 0.80,
    @impact          tinyint       = NULL,
    @likelihood      tinyint       = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    DECLARE @cat varchar(12) =
        CASE UPPER(LTRIM(RTRIM(COALESCE(@category,'Other'))))
            WHEN 'PRIVACY' THEN 'Privacy'
            WHEN 'SECURITY' THEN 'Security'
            WHEN 'COMPLIANCE' THEN 'Compliance'
            WHEN 'BIAS' THEN 'Bias'
            ELSE 'Other'
        END;

    DECLARE @sev varchar(12) =
        CASE UPPER(LTRIM(RTRIM(COALESCE(@severity,'Low'))))
            WHEN 'HIGH' THEN 'High'
            WHEN 'MEDIUM' THEN 'Medium'
            WHEN 'LOW' THEN 'Low'
            ELSE 'Low'
        END;

    DECLARE @conf decimal(5,3) =
        CASE
            WHEN @confidence IS NULL THEN 0.800
            WHEN @confidence < 0 THEN 0.000
            WHEN @confidence > 1 THEN 1.000
            ELSE CAST(@confidence AS decimal(5,3))
        END;

    DECLARE @impact_i int =
        COALESCE(@impact,
            CASE @sev
                WHEN 'High' THEN 9
                WHEN 'Medium' THEN 6
                WHEN 'Low' THEN 3
                ELSE 4
            END
        );

    DECLARE @likelihood_i int =
        COALESCE(@likelihood,
            CASE
                WHEN @conf >= 0.95 THEN 10
                WHEN @conf >= 0.85 THEN 9
                WHEN @conf >= 0.75 THEN 8
                WHEN @conf >= 0.65 THEN 7
                WHEN @conf >= 0.55 THEN 6
                WHEN @conf >= 0.45 THEN 5
                WHEN @conf >= 0.35 THEN 4
                WHEN @conf >= 0.25 THEN 3
                WHEN @conf >= 0.15 THEN 2
                ELSE 1
            END
        );

    SET @impact_i = CASE WHEN @impact_i < 0 THEN 0 WHEN @impact_i > 10 THEN 10 ELSE @impact_i END;
    SET @likelihood_i = CASE WHEN @likelihood_i < 0 THEN 0 WHEN @likelihood_i > 10 THEN 10 ELSE @likelihood_i END;

    IF EXISTS (SELECT 1 FROM uc1.Proposal WHERE project_number = @project_number)
        UPDATE uc1.Proposal
           SET title         = COALESCE(@title, title),
               business_unit = COALESCE(@business_unit, business_unit),
               language      = COALESCE(@language, language),
               updated_utc   = SYSUTCDATETIME()
         WHERE project_number = @project_number;
    ELSE
        INSERT INTO uc1.Proposal (project_number, title, business_unit, language, status, created_utc, updated_utc)
        VALUES (@project_number, @title, @business_unit, @language, 'In Progress', SYSUTCDATETIME(), SYSUTCDATETIME());

    IF NOT EXISTS (SELECT 1 FROM uc1.ReviewRun WHERE run_id = @run_id)
        INSERT INTO uc1.ReviewRun (run_id, project_number, high_count, med_count, low_count)
        VALUES (@run_id, @project_number, 0, 0, 0);

    DECLARE @existing_flag_id uniqueidentifier;
    DECLARE @result_flag_id uniqueidentifier;

    SELECT TOP (1) @existing_flag_id = f.flag_id
    FROM uc1.Flag f
    WHERE f.run_id = @run_id
      AND f.category = @cat
      AND f.severity = @sev
      AND f.issue = @issue;

    IF @existing_flag_id IS NOT NULL
    BEGIN
        UPDATE uc1.Flag
           SET rationale = @rationale,
               confidence = @conf,
               impact = CAST(@impact_i AS tinyint),
               likelihood = CAST(@likelihood_i AS tinyint)
         WHERE flag_id = @existing_flag_id;

        SET @result_flag_id = @existing_flag_id;
    END
    ELSE
    BEGIN
        DECLARE @raw_key varchar(64) = NULLIF(LTRIM(RTRIM(COALESCE(@flag_key, ''))), '');
        IF @raw_key IS NULL
            SET @raw_key = LOWER(CONCAT(@cat, '-', @sev));
        SET @raw_key = LEFT(@raw_key, 64);

        DECLARE @effective_key char(64) = @raw_key;
        IF EXISTS (SELECT 1 FROM uc1.Flag WHERE run_id = @run_id AND flag_key = @effective_key)
        BEGIN
            DECLARE @suffix char(8) = RIGHT(CONVERT(varchar(40), HASHBYTES('SHA1', CONCAT(@cat,'|',@sev,'|',@issue)), 2), 8);
            SET @effective_key = LEFT(@raw_key, 55) + '-' + @suffix;

            IF EXISTS (SELECT 1 FROM uc1.Flag WHERE run_id = @run_id AND flag_key = @effective_key)
                SET @effective_key = LEFT(@raw_key, 55) + '-' + RIGHT(REPLACE(CONVERT(varchar(36), NEWID()), '-', ''), 8);
        END

        DECLARE @ins TABLE(flag_id uniqueidentifier);
        INSERT INTO uc1.Flag
            (run_id, project_number, category, severity, issue, rationale, flag_key, confidence, impact, likelihood)
        OUTPUT inserted.flag_id INTO @ins(flag_id)
        VALUES
            (@run_id, @project_number, @cat, @sev, @issue, @rationale, @effective_key, @conf, CAST(@impact_i AS tinyint), CAST(@likelihood_i AS tinyint));

        SELECT TOP (1) @result_flag_id = flag_id FROM @ins;
    END;

    UPDATE rr
    SET
        rr.high_count = COALESCE(fc.high_count, 0),
        rr.med_count = COALESCE(fc.med_count, 0),
        rr.low_count = COALESCE(fc.low_count, 0),
        rr.overall_score = CAST(
            CASE
                WHEN COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0) + COALESCE(fc.low_count,0) = 0 THEN 0
                ELSE (1.0 * COALESCE(fc.high_count,0) + 0.7 * COALESCE(fc.med_count,0) + 0.3 * COALESCE(fc.low_count,0))
                     / NULLIF(COALESCE(fc.high_count,0) + COALESCE(fc.med_count,0) + COALESCE(fc.low_count,0), 0)
            END AS decimal(4,3)
        )
    FROM uc1.ReviewRun rr
    OUTER APPLY (
        SELECT
            SUM(CASE WHEN f.severity = 'High' THEN 1 ELSE 0 END) AS high_count,
            SUM(CASE WHEN f.severity = 'Medium' THEN 1 ELSE 0 END) AS med_count,
            SUM(CASE WHEN f.severity = 'Low' THEN 1 ELSE 0 END) AS low_count
        FROM uc1.Flag f
        WHERE f.run_id = rr.run_id
    ) fc
    WHERE rr.run_id = @run_id;

    COMMIT TRAN;

    SELECT CONVERT(varchar(36), @result_flag_id) AS flag_id;
END;

GO

IF OBJECT_ID('uc1.UpsertReview', 'P') IS NOT NULL DROP PROC uc1.UpsertReview;
GO
CREATE   PROC uc1.UpsertReview
 @project_number  nvarchar(100),
 @title           nvarchar(200)=NULL,
 @business_unit   nvarchar(100)=NULL,
 @language        char(2)=NULL,
 @overall_score   decimal(4,3)=NULL,
 @content_hash    char(64)=NULL,
 @model_id        nvarchar(100)=NULL,
 @prompt_version  nvarchar(50)=NULL,
 @high_count      int=0,
 @med_count       int=0,
 @low_count       int=0,
 @run_id          uniqueidentifier OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @calc_overall decimal(4,3);
  DECLARE @h int = CASE WHEN COALESCE(@high_count,0) < 0 THEN 0 ELSE COALESCE(@high_count,0) END;
  DECLARE @m int = CASE WHEN COALESCE(@med_count,0) < 0 THEN 0 ELSE COALESCE(@med_count,0) END;
  DECLARE @l int = CASE WHEN COALESCE(@low_count,0) < 0 THEN 0 ELSE COALESCE(@low_count,0) END;
  DECLARE @scored_total decimal(10,4) = @h + @m + @l;
  DECLARE @content_hash_clean char(64) = NULLIF(LTRIM(RTRIM(COALESCE(@content_hash,''))), '');

  IF @overall_score IS NOT NULL
      SET @calc_overall = CAST(CASE WHEN @overall_score < 0 THEN 0 WHEN @overall_score > 1 THEN 1 ELSE @overall_score END AS decimal(4,3));
  ELSE IF @scored_total = 0
      SET @calc_overall = 0;
  ELSE
  BEGIN
      DECLARE @weighted decimal(10,4) = (1.000 * @h) + (0.700 * @m) + (0.300 * @l);
      SET @calc_overall = CAST(CASE WHEN (@weighted / @scored_total) > 1 THEN 1 ELSE (@weighted / @scored_total) END AS decimal(4,3));
  END;

  MERGE uc1.Proposal AS t
  USING (SELECT @project_number AS project_number) s
    ON t.project_number = s.project_number
  WHEN MATCHED THEN UPDATE SET
    title = COALESCE(@title, t.title),
    business_unit = COALESCE(@business_unit, t.business_unit),
    language = COALESCE(@language, t.language),
    updated_utc = SYSUTCDATETIME()
  WHEN NOT MATCHED THEN INSERT(project_number,title,business_unit,language,status,created_utc,updated_utc)
    VALUES(@project_number,@title,@business_unit,@language,'In Progress',SYSUTCDATETIME(),SYSUTCDATETIME());

  SET @run_id = NEWID();
  INSERT uc1.ReviewRun(
      run_id, project_number, run_ts_utc, model_id, prompt_version, content_hash, overall_score,
      high_count, med_count, low_count, is_final
  )
  VALUES(
      @run_id, @project_number, SYSUTCDATETIME(), @model_id, @prompt_version, @content_hash_clean, @calc_overall,
      @h, @m, @l, 0
  );
END;

GO
