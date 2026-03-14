/* UC1 views (exported from live environment, sanitized packaging) */

IF OBJECT_ID('uc1.vw_DashboardMonthlyTrend', 'V') IS NOT NULL DROP VIEW uc1.vw_DashboardMonthlyTrend;
GO
CREATE   VIEW uc1.vw_DashboardMonthlyTrend AS
    SELECT
        DATEFROMPARTS(YEAR(ps.run_ts_utc), MONTH(ps.run_ts_utc), 1) AS month_start_utc,
        COUNT(*) AS total_proposals,
        CAST(AVG(COALESCE(ps.RiskScore, 0)) AS decimal(6,3)) AS avg_risk_score,
        CAST(100.0 * SUM(CASE WHEN ps.ComplianceStatus='Non-compliant' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS decimal(6,2)) AS non_compliant_pct
    FROM uc1.vw_ProposalSummary ps
    GROUP BY DATEFROMPARTS(YEAR(ps.run_ts_utc), MONTH(ps.run_ts_utc), 1);

GO

IF OBJECT_ID('uc1.vw_DashboardRiskTypeSeverity', 'V') IS NOT NULL DROP VIEW uc1.vw_DashboardRiskTypeSeverity;
GO
CREATE   VIEW uc1.vw_DashboardRiskTypeSeverity AS
    SELECT
        rr.run_id,
        rr.run_ts_utc,
        rr.project_number,
        p.business_unit,
        f.category AS risk_type,
        f.severity,
        COUNT(*) AS flag_count
    FROM uc1.Flag f
    JOIN uc1.ReviewRun rr ON rr.run_id=f.run_id
    JOIN uc1.Proposal p ON p.project_number=rr.project_number
    WHERE f.severity IN ('High','Medium','Low')
    GROUP BY rr.run_id, rr.run_ts_utc, rr.project_number, p.business_unit, f.category, f.severity;

GO

IF OBJECT_ID('uc1.vw_FlagList', 'V') IS NOT NULL DROP VIEW uc1.vw_FlagList;
GO
CREATE   VIEW uc1.vw_FlagList AS
    WITH citation_rollup AS (
        SELECT c.flag_id, COUNT(*) AS citation_count, MIN(c.citation_id) AS first_citation_id
        FROM uc1.Citation c
        GROUP BY c.flag_id
    )
    SELECT
        rr.project_number,
        p.title,
        p.business_unit,
        p.language,
        rr.run_id,
        rr.run_ts_utc,
        rr.model_id,
        rr.prompt_version,
        rr.overall_score,
        f.flag_id,
        f.category,
        f.severity,
        f.issue,
        f.rationale,
        f.confidence,
        f.impact,
        f.likelihood,
        CAST(CASE WHEN f.impact IS NULL OR f.likelihood IS NULL THEN NULL ELSE (f.impact * f.likelihood) / 100.0 END AS decimal(5,3)) AS flag_risk_score,
        COALESCE(cr.citation_count,0) AS citation_count,
        c.doc_title,
        c.page,
        c.source_type,
        c.policy_reference,
        c.language AS citation_lang
    FROM uc1.ReviewRun rr
    JOIN uc1.Proposal p ON p.project_number = rr.project_number
    JOIN uc1.Flag f ON f.run_id = rr.run_id
    LEFT JOIN citation_rollup cr ON cr.flag_id = f.flag_id
    LEFT JOIN uc1.Citation c ON c.citation_id = cr.first_citation_id
    WHERE f.severity IN ('High','Medium','Low');

GO

IF OBJECT_ID('uc1.vw_ProjectRiskMatrix', 'V') IS NOT NULL DROP VIEW uc1.vw_ProjectRiskMatrix;
GO
CREATE   VIEW uc1.vw_ProjectRiskMatrix AS
WITH latest_run AS (
    SELECT rr.*, ROW_NUMBER() OVER (PARTITION BY rr.project_number ORDER BY rr.run_ts_utc DESC, rr.run_id DESC) AS rn
    FROM uc1.ReviewRun rr
),
flag_norm AS (
    SELECT
        f.run_id,
        f.category,
        f.severity,
        CAST(
            COALESCE(
                CAST(f.impact AS decimal(10,3)),
                CASE UPPER(f.severity)
                    WHEN 'HIGH' THEN 9.000
                    WHEN 'MEDIUM' THEN 6.000
                    WHEN 'LOW' THEN 3.000
                    ELSE 4.000
                END
            ) AS decimal(10,3)
        ) AS impact_norm,
        CAST(
            COALESCE(
                CAST(f.likelihood AS decimal(10,3)),
                CASE
                    WHEN COALESCE(f.confidence, 0.8) >= 0.95 THEN 10.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.85 THEN 9.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.75 THEN 8.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.65 THEN 7.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.55 THEN 6.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.45 THEN 5.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.35 THEN 4.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.25 THEN 3.000
                    WHEN COALESCE(f.confidence, 0.8) >= 0.15 THEN 2.000
                    ELSE 1.000
                END
            ) AS decimal(10,3)
        ) AS likelihood_norm,
        CAST(
            CASE UPPER(f.severity)
                WHEN 'HIGH' THEN 1.000
                WHEN 'MEDIUM' THEN 0.700
                WHEN 'LOW' THEN 0.300
                ELSE 0.000
            END AS decimal(10,3)
        ) AS severity_weight
    FROM uc1.Flag f
    WHERE f.severity IN ('High','Medium','Low')
),
run_agg AS (
    SELECT
        fn.run_id,
        COUNT(*) AS total_flags,
        SUM(CASE WHEN fn.severity = 'High' THEN 1 ELSE 0 END) AS high_flags,
        SUM(CASE WHEN fn.severity = 'Medium' THEN 1 ELSE 0 END) AS medium_flags,
        SUM(CASE WHEN fn.severity = 'Low' THEN 1 ELSE 0 END) AS low_flags,
        SUM(CASE WHEN fn.category = 'Bias' THEN 1 ELSE 0 END) AS bias_flags,
        SUM(CASE WHEN fn.category = 'Other' THEN 1 ELSE 0 END) AS other_flags,
        MAX(fn.impact_norm) AS project_impact,
        CASE
            WHEN SUM(fn.severity_weight)=0 THEN CAST(0 AS decimal(10,3))
            ELSE SUM(fn.severity_weight * fn.likelihood_norm) / SUM(fn.severity_weight)
        END AS project_likelihood
    FROM flag_norm fn
    GROUP BY fn.run_id
)
SELECT
    p.project_number,
    p.title,
    p.business_unit,
    p.language,
    lr.run_id,
    lr.run_ts_utc,
    CAST(COALESCE(ra.project_impact, 0) AS decimal(5,2)) AS project_impact,
    CAST(COALESCE(ra.project_likelihood, 0) AS decimal(5,2)) AS project_likelihood,
    COALESCE(ra.total_flags, 0) AS total_flags,
    COALESCE(ra.high_flags, 0) AS high_flags,
    COALESCE(ra.medium_flags, 0) AS medium_flags,
    COALESCE(ra.low_flags, 0) AS low_flags,
    COALESCE(ra.bias_flags, 0) AS bias_flags,
    COALESCE(ra.other_flags, 0) AS other_flags,
    CAST(
        CASE
            WHEN COALESCE(ra.total_flags,0)=0 THEN 0
            ELSE (1.0 * COALESCE(ra.high_flags,0) + 0.7 * COALESCE(ra.medium_flags,0) + 0.3 * COALESCE(ra.low_flags,0)) / NULLIF(COALESCE(ra.total_flags,0),0)
        END AS decimal(4,3)
    ) AS risk_score,
    CASE WHEN (COALESCE(ra.high_flags,0) + COALESCE(ra.medium_flags,0)) > 0 THEN 'Non-compliant' ELSE 'Compliant' END AS compliance_status,
    CASE
        WHEN COALESCE(ra.high_flags,0) > 0 THEN 'High'
        WHEN COALESCE(ra.medium_flags,0) > 0 THEN 'Medium'
        WHEN COALESCE(ra.low_flags,0) > 0 THEN 'Low'
        ELSE 'None'
    END AS risk_level,
    COALESCE(lr.consistency_status, 'Baseline') AS consistency_status,
    COALESCE(lr.is_drift, 0) AS is_drift
FROM latest_run lr
JOIN uc1.Proposal p ON p.project_number = lr.project_number
LEFT JOIN run_agg ra ON ra.run_id = lr.run_id
WHERE lr.rn = 1;

GO

IF OBJECT_ID('uc1.vw_ProposalSummary', 'V') IS NOT NULL DROP VIEW uc1.vw_ProposalSummary;
GO
CREATE   VIEW uc1.vw_ProposalSummary AS
WITH latest_run AS (
  SELECT rr.*, ROW_NUMBER() OVER (PARTITION BY rr.project_number ORDER BY rr.run_ts_utc DESC, rr.run_id DESC) AS rn
  FROM uc1.ReviewRun rr
),
run_flag AS (
  SELECT
      f.run_id,
      SUM(CASE WHEN f.severity='High' THEN 1 ELSE 0 END) AS HighFlags,
      SUM(CASE WHEN f.severity='Medium' THEN 1 ELSE 0 END) AS MediumFlags,
      SUM(CASE WHEN f.severity='Low' THEN 1 ELSE 0 END) AS LowFlags,
      SUM(CASE WHEN f.category='Bias' THEN 1 ELSE 0 END) AS BiasRisks,
      CAST(AVG(CAST(f.confidence AS decimal(9,4))) AS decimal(6,3)) AS AvgConfidence,
      CAST(AVG(CAST(f.impact AS decimal(9,4))) AS decimal(6,3)) AS AvgImpact,
      CAST(AVG(CAST(f.likelihood AS decimal(9,4))) AS decimal(6,3)) AS AvgLikelihood
  FROM uc1.Flag f
  GROUP BY f.run_id
),
run_cited AS (
  SELECT f.run_id,
         COUNT(DISTINCT f.flag_id) AS LoggedFlags,
         COUNT(DISTINCT CASE WHEN c.flag_id IS NOT NULL THEN f.flag_id END) AS CitedFlags
  FROM uc1.Flag f
  LEFT JOIN uc1.Citation c ON c.flag_id=f.flag_id
  GROUP BY f.run_id
)
SELECT
    p.project_number,
    p.title,
    p.business_unit,
    p.language,
    p.status,
    lr.run_id,
    lr.run_ts_utc,
    CAST(
      CASE
        WHEN COALESCE(rf.HighFlags,0) + COALESCE(rf.MediumFlags,0) + COALESCE(rf.LowFlags,0) = 0 THEN 0
        ELSE (1.0 * COALESCE(rf.HighFlags,0) + 0.7 * COALESCE(rf.MediumFlags,0) + 0.3 * COALESCE(rf.LowFlags,0))
             / NULLIF(COALESCE(rf.HighFlags,0) + COALESCE(rf.MediumFlags,0) + COALESCE(rf.LowFlags,0),0)
      END AS decimal(4,3)
    ) AS RiskScore,
    COALESCE(rf.HighFlags,0) AS HighFlags,
    COALESCE(rf.MediumFlags,0) AS MediumFlags,
    COALESCE(rf.LowFlags,0) AS LowFlags,
    (COALESCE(rf.HighFlags,0) + COALESCE(rf.MediumFlags,0) + COALESCE(rf.LowFlags,0)) AS TotalFlags,
    COALESCE(rf.BiasRisks, 0) AS BiasRisks,
    CAST(
      CASE
        WHEN COALESCE(rc.LoggedFlags,0) = 0 THEN 0
        ELSE (100.0 * COALESCE(rc.CitedFlags,0) / rc.LoggedFlags)
      END AS decimal(6,2)
    ) AS CitationCoveragePct,
    COALESCE(rf.AvgConfidence, 0) AS AvgConfidence,
    COALESCE(rf.AvgImpact, 0) AS AvgImpact,
    COALESCE(rf.AvgLikelihood, 0) AS AvgLikelihood,
    CASE
        WHEN COALESCE(rf.HighFlags,0) > 0 THEN 'High'
        WHEN COALESCE(rf.MediumFlags,0) > 0 THEN 'Medium'
        WHEN COALESCE(rf.LowFlags,0) > 0 THEN 'Low'
        ELSE 'None'
    END AS RiskLevel,
    CASE WHEN (COALESCE(rf.HighFlags,0) + COALESCE(rf.MediumFlags,0)) > 0 THEN 'Non-compliant' ELSE 'Compliant' END AS ComplianceStatus,
    COALESCE(lr.consistency_status, 'Baseline') AS consistency_status,
    COALESCE(lr.is_drift, 0) AS is_drift
FROM latest_run lr
JOIN uc1.Proposal p ON p.project_number=lr.project_number
LEFT JOIN run_flag rf ON rf.run_id=lr.run_id
LEFT JOIN run_cited rc ON rc.run_id=lr.run_id
WHERE lr.rn=1;

GO
