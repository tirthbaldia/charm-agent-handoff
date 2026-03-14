/*
UC1 schema bootstrap (sanitized template)
Order: schema -> base tables -> FKs -> CHECKS -> indexes
*/

SET XACT_ABORT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'uc1')
    EXEC('CREATE SCHEMA uc1');
GO

/* Drop in dependency order for clean rebuilds */
IF OBJECT_ID('uc1.Citation', 'U') IS NOT NULL DROP TABLE uc1.Citation;
IF OBJECT_ID('uc1.Flag', 'U') IS NOT NULL DROP TABLE uc1.Flag;
IF OBJECT_ID('uc1.ReviewRun', 'U') IS NOT NULL DROP TABLE uc1.ReviewRun;
IF OBJECT_ID('uc1.Proposal', 'U') IS NOT NULL DROP TABLE uc1.Proposal;
GO

CREATE TABLE uc1.Proposal (
    project_number  nvarchar(100) NOT NULL,
    title           nvarchar(200) NULL,
    business_unit   nvarchar(100) NULL,
    language        char(2) NULL,
    status          nvarchar(30) NOT NULL CONSTRAINT DF_Proposal_Status DEFAULT ('In Progress'),
    created_utc     datetime2(3) NOT NULL CONSTRAINT DF_Proposal_CreatedUtc DEFAULT (sysutcdatetime()),
    updated_utc     datetime2(3) NOT NULL CONSTRAINT DF_Proposal_UpdatedUtc DEFAULT (sysutcdatetime()),
    row_ver         rowversion NOT NULL,
    CONSTRAINT PK_Proposal PRIMARY KEY (project_number)
);
GO

CREATE TABLE uc1.ReviewRun (
    run_id               uniqueidentifier NOT NULL CONSTRAINT DF_ReviewRun_RunId DEFAULT (newid()),
    project_number       nvarchar(100) NOT NULL,
    run_ts_utc           datetime2(3) NOT NULL CONSTRAINT DF_ReviewRun_RunTs DEFAULT (sysutcdatetime()),
    model_id             nvarchar(100) NULL,
    prompt_version       nvarchar(50) NULL,
    content_hash         char(64) NULL,
    overall_score        decimal(4,3) NULL,
    high_count           int NOT NULL CONSTRAINT DF_ReviewRun_HighCount DEFAULT ((0)),
    med_count            int NOT NULL CONSTRAINT DF_ReviewRun_MedCount DEFAULT ((0)),
    low_count            int NOT NULL CONSTRAINT DF_ReviewRun_LowCount DEFAULT ((0)),
    is_final             bit NOT NULL CONSTRAINT DF_ReviewRun_IsFinal DEFAULT ((0)),
    run_signature_hash   char(64) NULL,
    is_drift             bit NOT NULL CONSTRAINT DF_ReviewRun_IsDrift DEFAULT ((0)),
    baseline_run_id      uniqueidentifier NULL,
    consistency_status   varchar(20) NOT NULL CONSTRAINT DF_ReviewRun_ConsistencyStatus DEFAULT ('Baseline'),
    CONSTRAINT PK_ReviewRun PRIMARY KEY (run_id),
    CONSTRAINT FK_ReviewRun_Proposal FOREIGN KEY (project_number) REFERENCES uc1.Proposal(project_number),
    CONSTRAINT FK_ReviewRun_BaselineRun FOREIGN KEY (baseline_run_id) REFERENCES uc1.ReviewRun(run_id),
    CONSTRAINT CK_ReviewRun_ConsistencyStatus CHECK (consistency_status IN ('Baseline','Match','Drift'))
);
GO

CREATE TABLE uc1.Flag (
    flag_id          uniqueidentifier NOT NULL CONSTRAINT DF_Flag_FlagId DEFAULT (newid()),
    run_id           uniqueidentifier NOT NULL,
    project_number   nvarchar(100) NOT NULL,
    category         varchar(12) NOT NULL,
    severity         varchar(12) NOT NULL,
    issue            nvarchar(400) NOT NULL,
    rationale        nvarchar(1000) NULL,
    confidence       decimal(4,3) NULL,
    flag_key         char(64) NOT NULL,
    impact           tinyint NULL,
    likelihood       tinyint NULL,
    CONSTRAINT PK_Flag PRIMARY KEY (flag_id),
    CONSTRAINT FK_Flag_Run FOREIGN KEY (run_id) REFERENCES uc1.ReviewRun(run_id),
    CONSTRAINT CK_Flag_Category CHECK (category IN ('Privacy','Security','Compliance','Bias','Other')),
    CONSTRAINT CK_Flag_Severity CHECK (severity IN ('High','Medium','Low')),
    CONSTRAINT CK_Flag_Impact CHECK (impact IS NULL OR (impact BETWEEN 0 AND 10)),
    CONSTRAINT CK_Flag_Likelihood CHECK (likelihood IS NULL OR (likelihood BETWEEN 0 AND 10))
);
GO

CREATE TABLE uc1.Citation (
    citation_id      uniqueidentifier NOT NULL CONSTRAINT DF_Citation_CitationId DEFAULT (newid()),
    flag_id          uniqueidentifier NOT NULL,
    doc_title        nvarchar(255) NOT NULL,
    page             int NULL,
    source_url       nvarchar(2048) NULL,
    source_type      varchar(16) NOT NULL,
    requirement_id   nvarchar(50) NULL,
    clause_id        nvarchar(50) NULL,
    language         char(2) NULL,
    CONSTRAINT PK_Citation PRIMARY KEY (citation_id),
    CONSTRAINT FK_Citation_Flag FOREIGN KEY (flag_id) REFERENCES uc1.Flag(flag_id),
    CONSTRAINT CK_Citation_SourceType CHECK (source_type IN ('internal_rubric','external'))
);
GO

/* Indexes from current live model */
CREATE INDEX IX_ReviewRun_ProjectTime ON uc1.ReviewRun(project_number, run_ts_utc);
CREATE INDEX IX_Flag_ProjectSeverity ON uc1.Flag(project_number, severity);
CREATE INDEX IX_Flag_Category ON uc1.Flag(category);
CREATE UNIQUE INDEX UX_Flag_Run_FlagKey ON uc1.Flag(run_id, flag_key);
CREATE INDEX IX_Citation_Flag ON uc1.Citation(flag_id);
GO

/* Post-deploy smoke checks */
SELECT 'Tables' AS object_type, name FROM sys.tables WHERE schema_id = SCHEMA_ID('uc1') ORDER BY name;
SELECT 'Views' AS object_type, name FROM sys.views WHERE schema_id = SCHEMA_ID('uc1') ORDER BY name;
SELECT 'Procedures' AS object_type, name FROM sys.procedures WHERE schema_id = SCHEMA_ID('uc1') ORDER BY name;
GO
