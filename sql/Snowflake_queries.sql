CREATE DATABASE IF NOT EXISTS SEMANTIC_DEMO;

CREATE SCHEMA IF NOT EXISTS SEMANTIC_DEMO.SALES;

USE DATABASE SEMANTIC_DEMO;
USE SCHEMA SALES;

-- Table 1: CLIENTS
CREATE OR REPLACE TABLE CLIENTS (
    CLIENT_ID VARCHAR(10) PRIMARY KEY,
    CLIENT_NAME VARCHAR(100) NOT NULL,
    INDUSTRY VARCHAR(50)
);

-- Table 2: OPPORTUNITIES
CREATE OR REPLACE TABLE OPPORTUNITIES (
    OPP_ID VARCHAR(10) PRIMARY KEY,
    CLIENT_ID VARCHAR(10),
    OPP_NAME VARCHAR(150),
    AMOUNT NUMBER(15,2),
    FOREIGN KEY (CLIENT_ID)
        REFERENCES CLIENTS(CLIENT_ID)
);

-- Table 3: REVENUE
CREATE OR REPLACE TABLE REVENUE (
    REV_ID VARCHAR(10) PRIMARY KEY,
    OPP_ID VARCHAR(10),
    ACTUAL_REVENUE NUMBER(15,2),
    FOREIGN KEY (OPP_ID)
        REFERENCES OPPORTUNITIES(OPP_ID)
);

-- Table 4: RISKS
CREATE OR REPLACE TABLE RISKS (
    RISK_ID VARCHAR(10) PRIMARY KEY,
    OPP_ID VARCHAR(10),
    RISK_LEVEL VARCHAR(20),
    DESCRIPTION VARCHAR(255),
    FOREIGN KEY (OPP_ID)
        REFERENCES OPPORTUNITIES(OPP_ID)
);

-- CLIENTS
INSERT INTO CLIENTS
    (CLIENT_ID, CLIENT_NAME, INDUSTRY)
VALUES
    ('C001', 'ABC Corporation', 'Banking'),
    ('C002', 'XYZ Technologies', 'IT'),
    ('C003', 'Global Finance', 'Finance');


-- OPPORTUNITIES
INSERT INTO OPPORTUNITIES
    (OPP_ID, CLIENT_ID, OPP_NAME, AMOUNT)
VALUES
    ('O101', 'C001', 'Cloud Migration', 500000),
    ('O102', 'C001', 'Data Modernization', 300000),
    ('O103', 'C002', 'AI Implementation', 700000),
    ('O104', 'C003', 'Security Upgrade', 200000);

-- REVENUE
INSERT INTO REVENUE
    (REV_ID, OPP_ID, ACTUAL_REVENUE)
VALUES
    ('R001', 'O101', 350000),
    ('R002', 'O102', 150000),
    ('R003', 'O103', 500000),
    ('R004', 'O104', 100000);

-- RISKS
INSERT INTO RISKS
    (RISK_ID, OPP_ID, RISK_LEVEL, DESCRIPTION)
VALUES
    ('K001', 'O101', 'High', 'Resource shortage'),
    ('K002', 'O102', 'Low', 'Minor schedule delay'),
    ('K003', 'O103', 'Medium', 'Budget approval pending'),
    ('K004', 'O104', 'High', 'Security compliance issue');


SELECT * FROM CLIENTS;
SELECT * FROM OPPORTUNITIES;
SELECT * FROM REVENUE;
SELECT * FROM RISKS;


SELECT
    c.CLIENT_ID,
    c.CLIENT_NAME,
    SUM(r.ACTUAL_REVENUE) AS TOTAL_REVENUE
FROM CLIENTS c
JOIN OPPORTUNITIES o
    ON c.CLIENT_ID = o.CLIENT_ID
JOIN REVENUE r
    ON o.OPP_ID = r.OPP_ID
GROUP BY c.CLIENT_ID, c.CLIENT_NAME
ORDER BY TOTAL_REVENUE DESC;


SELECT
    c.CLIENT_NAME,
    o.OPP_NAME,
    o.AMOUNT,
    rk.RISK_LEVEL,
    rk.DESCRIPTION
FROM CLIENTS c
JOIN OPPORTUNITIES o
    ON c.CLIENT_ID = o.CLIENT_ID
JOIN RISKS rk
    ON o.OPP_ID = rk.OPP_ID
WHERE UPPER(rk.RISK_LEVEL) = 'HIGH';



SELECT
    c.CLIENT_NAME,
    c.INDUSTRY,
    o.OPP_ID,
    o.OPP_NAME,
    o.AMOUNT AS OPPORTUNITY_AMOUNT,
    r.ACTUAL_REVENUE,
    rk.RISK_LEVEL,
    rk.DESCRIPTION AS RISK_DESCRIPTION
FROM CLIENTS c
LEFT JOIN OPPORTUNITIES o
    ON c.CLIENT_ID = o.CLIENT_ID
LEFT JOIN REVENUE r
    ON o.OPP_ID = r.OPP_ID
LEFT JOIN RISKS rk
    ON o.OPP_ID = rk.OPP_ID
ORDER BY c.CLIENT_NAME, o.OPP_ID;



CREATE OR REPLACE VIEW VW_CLIENT_OPPORTUNITY_SUMMARY AS
SELECT
    c.CLIENT_ID,
    c.CLIENT_NAME,
    c.INDUSTRY,
    o.OPP_ID,
    o.OPP_NAME,
    o.AMOUNT AS OPPORTUNITY_AMOUNT,
    r.ACTUAL_REVENUE,
    rk.RISK_LEVEL,
    rk.DESCRIPTION AS RISK_DESCRIPTION
FROM CLIENTS c
LEFT JOIN OPPORTUNITIES o
    ON c.CLIENT_ID = o.CLIENT_ID
LEFT JOIN REVENUE r
    ON o.OPP_ID = r.OPP_ID
LEFT JOIN RISKS rk
    ON o.OPP_ID = rk.OPP_ID;

SELECT *
FROM SEMANTIC_DEMO.SALES.VW_CLIENT_OPPORTUNITY_SUMMARY;



USE DATABASE SEMANTIC_DEMO;
USE SCHEMA SALES;

CREATE OR REPLACE SEMANTIC VIEW
    SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS

TABLES (
    clients AS SEMANTIC_DEMO.SALES.CLIENTS PRIMARY KEY (CLIENT_ID),
    opportunities AS SEMANTIC_DEMO.SALES.OPPORTUNITIES PRIMARY KEY (OPP_ID)
)

RELATIONSHIPS (   opportunity_client AS      opportunities (CLIENT_ID)     REFERENCES clients )

FACTS ( opportunities.opportunity_amount AS AMOUNT )

DIMENSIONS (
    clients.client_name AS CLIENT_NAME,
    clients.industry AS INDUSTRY,
    opportunities.opportunity_name AS OPP_NAME
)

METRICS (
    opportunities.total_pipeline AS SUM(AMOUNT),
    opportunities.opportunity_count AS COUNT(OPP_ID)
)

COMMENT = 'Business semantic layer for client and sales opportunity analysis';



SHOW SEMANTIC VIEWS IN SCHEMA SEMANTIC_DEMO.SALES;

DESCRIBE SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS;

DESCRIBE VIEW SEMANTIC_DEMO.SALES.VW_CLIENT_OPPORTUNITY_SUMMARY;



-- this is to create Snowflak MCP server -- 

CREATE OR REPLACE MCP SERVER
    SEMANTIC_DEMO.SALES.SALES_MCP_SERVER
FROM SPECIFICATION $$
tools:
  - name: "sales_analytics"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS"
    description: "Answer questions about clients, opportunities, industries and sales pipeline"
    title: "Sales Analytics"
$$;


SELECT
    CURRENT_ORGANIZATION_NAME() AS ORG_NAME,
    CURRENT_ACCOUNT_NAME() AS ACCOUNT_NAME,
    CURRENT_USER() AS USER_NAME,
    CURRENT_WAREHOUSE() AS WAREHOUSE_NAME,
    CURRENT_DATABASE() AS DATABASE_NAME,
    CURRENT_ACCOUNT() AS ACCOUNT_LOCATOR;



CREATE SECURITY INTEGRATION MCP_OAUTH
  TYPE = OAUTH
  ENABLED = TRUE
  OAUTH_CLIENT = CUSTOM
  OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
  OAUTH_REDIRECT_URI = 'https://<account-name>.snowflakecomputing.com/'
  OAUTH_ISSUE_REFRESH_TOKENS = TRUE;

-- TO COLLECT THE MCP SECRETS --- 
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('MCP_OAUTH');


CREATE ROLE IF NOT EXISTS MCP_READER_ROLE;

GRANT USAGE ON WAREHOUSE SNOWFLAKE_LEARNING_WH TO ROLE MCP_READER_ROLE;

GRANT USAGE ON DATABASE SEMANTIC_DEMO TO ROLE MCP_READER_ROLE;

GRANT USAGE ON SCHEMA SEMANTIC_DEMO.SALES TO ROLE MCP_READER_ROLE;

GRANT SELECT ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE MCP_READER_ROLE;



--------------------------------------------------------------------------------
-- TO CREATE AN SERVICE ACCOUNT TO ACCESS THE DB AND SEMENTIC VIEW 

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS SNOWFLAKEIQ_ROLE;

CREATE USER IF NOT EXISTS SNOWFLAKEIQ_SVC
    TYPE = SERVICE
    DEFAULT_ROLE = SNOWFLAKEIQ_ROLE
    COMMENT = 'Service account for SnowflakeIQ application';

GRANT ROLE SNOWFLAKEIQ_ROLE TO USER SNOWFLAKEIQ_SVC;



USE ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE SEMANTIC_DEMO
    TO ROLE SNOWFLAKEIQ_ROLE;

GRANT USAGE ON SCHEMA SEMANTIC_DEMO.SALES
    TO ROLE SNOWFLAKEIQ_ROLE;

GRANT REFERENCES ON SEMANTIC VIEW
    SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS
    TO ROLE SNOWFLAKEIQ_ROLE;

----------------------------------------------------------------------------------------------

SHOW WAREHOUSES;


ALTER USER "SNOWFLAKEIQ_SVC" SET RSA_PUBLIC_KEY='MIIBI*';

  
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();

DESC USER "SNOWFLAKEIQ_SVC";

select sysdate() from dual;

GRANT SELECT ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON TABLE SEMANTIC_DEMO.SALES.OPPORTUNITIES TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON TABLE SEMANTIC_DEMO.SALES.CLIENTS TO ROLE SNOWFLAKEIQ_ROLE;
GRANT USAGE ON WAREHOUSE SNOWFLAKE_LEARNING_WH TO ROLE SNOWFLAKEIQ_ROLE;



INSERT INTO CLIENTS (CLIENT_ID, CLIENT_NAME, INDUSTRY)
VALUES ('C004', 'Nvidia Corporation', 'Semi-Conductor');


-- OPPORTUNITIES
INSERT INTO OPPORTUNITIES
    (OPP_ID, CLIENT_ID, OPP_NAME, AMOUNT)
VALUES
    ('O104', 'C004', 'New Datacenter', 550000);

UPDATE OPPORTUNITIES SET OPP_ID='0105' where client_id='C004' and opp_name='New Datacenter';


SELECT * FROM OPPORTUNITIES;

SELECT *
FROM SEMANTIC_VIEW(
    SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS
    METRICS total_pipeline
    DIMENSIONS clients.client_name
)
ORDER BY total_pipeline DESC NULLS LAST;

DESCRIBE TABLE SEMANTIC_DEMO.SALES.RISKS;

USE ROLE SECURITYADMIN;

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SEMANTIC VIEW
    SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS
TABLES (
    clients AS SEMANTIC_DEMO.SALES.CLIENTS PRIMARY KEY (CLIENT_ID),
    opportunities AS SEMANTIC_DEMO.SALES.OPPORTUNITIES PRIMARY KEY (OPP_ID),
    risks AS SEMANTIC_DEMO.SALES.RISKS PRIMARY KEY (RISK_ID)          -- adjust
)
RELATIONSHIPS (
    opportunity_client AS opportunities (CLIENT_ID) REFERENCES clients,
    risk_opportunity AS risks (OPP_ID) REFERENCES opportunities       -- adjust
)
FACTS ( opportunities.opportunity_amount AS AMOUNT )
DIMENSIONS (
    clients.client_id AS CLIENT_ID,
    clients.client_name AS CLIENT_NAME,
    clients.industry AS INDUSTRY,
    opportunities.opportunity_name AS OPP_NAME,
    risks.risk_level AS RISK_LEVEL,
    risks.risk_description AS DESCRIPTION
)
METRICS (
    opportunities.total_pipeline AS SUM(AMOUNT),
    opportunities.opportunity_count AS COUNT(OPP_ID),
    risks.risk_count AS COUNT(RISK_ID)                                -- adjust
)
COMMENT = 'Business semantic layer for client, sales opportunity and risk analysis';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON TABLE SEMANTIC_DEMO.SALES.RISKS TO ROLE SNOWFLAKEIQ_ROLE;

--11/13/2026

UPDATE SEMANTIC_DEMO.SALES.OPPORTUNITIES SET OPP_ID = 'O105' WHERE OPP_ID = '0105';
SELECT * FROM SEMANTIC_DEMO.SALES.OPPORTUNITIES;


CREATE OR REPLACE SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS
TABLES (
    clients AS SEMANTIC_DEMO.SALES.CLIENTS PRIMARY KEY (CLIENT_ID)
        WITH SYNONYMS ('customers', 'accounts')
        COMMENT = 'Companies we sell to',
    opportunities AS SEMANTIC_DEMO.SALES.OPPORTUNITIES PRIMARY KEY (OPP_ID)
        WITH SYNONYMS ('deals', 'pipeline')
        COMMENT = 'Sales opportunities, each belonging to one client',
    revenue AS SEMANTIC_DEMO.SALES.REVENUE PRIMARY KEY (REV_ID)
        COMMENT = 'Actual revenue recognized for an opportunity',
    risks AS SEMANTIC_DEMO.SALES.RISKS PRIMARY KEY (RISK_ID)
        WITH SYNONYMS ('issues', 'concerns')
        COMMENT = 'Risks recorded against an opportunity'
)
RELATIONSHIPS (
    opportunity_client AS opportunities (CLIENT_ID) REFERENCES clients,
    revenue_opportunity AS revenue (OPP_ID) REFERENCES opportunities,
    risk_opportunity AS risks (OPP_ID) REFERENCES opportunities
)
FACTS (
    opportunities.opportunity_amount AS AMOUNT
        COMMENT = 'Expected value of the opportunity in USD',
    revenue.revenue_amount AS ACTUAL_REVENUE
        COMMENT = 'Revenue actually earned in USD'
)
DIMENSIONS (
    clients.client_id AS CLIENT_ID,
    clients.client_name AS CLIENT_NAME
        WITH SYNONYMS ('customer name', 'account name'),
    clients.industry AS INDUSTRY
        WITH SYNONYMS ('sector', 'vertical'),
    opportunities.opportunity_id AS OPP_ID,
    opportunities.opportunity_name AS OPP_NAME
        WITH SYNONYMS ('deal name', 'project'),
    risks.risk_level AS RISK_LEVEL
        WITH SYNONYMS ('severity', 'risk rating')
        COMMENT = 'One of High, Medium or Low',
    risks.risk_description AS DESCRIPTION
)
METRICS (
    clients.client_count AS COUNT(CLIENT_ID),
    opportunities.total_pipeline AS SUM(AMOUNT)
        WITH SYNONYMS ('pipeline value', 'total deal value')
        COMMENT = 'Sum of expected opportunity amounts',
    opportunities.opportunity_count AS COUNT(OPP_ID)
        WITH SYNONYMS ('number of deals'),
    opportunities.average_deal_size AS AVG(AMOUNT),
    revenue.total_revenue AS SUM(ACTUAL_REVENUE)
        WITH SYNONYMS ('actual revenue', 'earned revenue'),
    risks.risk_count AS COUNT(RISK_ID),
    risks.high_risk_count AS COUNT_IF(UPPER(RISK_LEVEL) = 'HIGH'),
    revenue_to_pipeline_ratio AS DIV0(revenue.total_revenue, opportunities.total_pipeline)
        COMMENT = 'Share of expected pipeline that became actual revenue'
)
COMMENT = 'Business semantic layer for client, opportunity, revenue and risk analysis';


GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON TABLE SEMANTIC_DEMO.SALES.REVENUE TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE MCP_READER_ROLE;

ALTER TABLE OPPORTUNITIES ADD COLUMN
    STAGE VARCHAR(30),
    OWNER VARCHAR(100),
    CREATED_DATE DATE,
    CLOSE_DATE DATE;

UPDATE OPPORTUNITIES SET STAGE = 'Closed Won',  OWNER = 'Priya Nair',   CREATED_DATE = '2026-02-10', CLOSE_DATE = '2026-06-30' WHERE OPP_ID = 'O101';
UPDATE OPPORTUNITIES SET STAGE = 'Negotiation', OWNER = 'Priya Nair',   CREATED_DATE = '2026-05-05', CLOSE_DATE = '2026-12-15' WHERE OPP_ID = 'O102';
UPDATE OPPORTUNITIES SET STAGE = 'Proposal',    OWNER = 'David Chen',   CREATED_DATE = '2026-07-20', CLOSE_DATE = '2027-01-31' WHERE OPP_ID = 'O103';
UPDATE OPPORTUNITIES SET STAGE = 'Closed Lost', OWNER = 'Maria Lopez',  CREATED_DATE = '2026-03-15', CLOSE_DATE = '2026-08-20' WHERE OPP_ID = 'O104';
UPDATE OPPORTUNITIES SET STAGE = 'Prospecting', OWNER = 'David Chen',   CREATED_DATE = '2026-10-01', CLOSE_DATE = '2027-03-31' WHERE OPP_ID = 'O105';

SELECT * FROM OPPORTUNITIES ORDER BY OPP_ID;

UPDATE CLIENTS SET CLIENT_NAME = 'Vnidia Corporation' WHERE CLIENT_ID = 'C004';
SELECT * FROM CLIENTS ORDER BY CLIENT_ID;
    
CREATE OR REPLACE SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS
TABLES (
    clients AS SEMANTIC_DEMO.SALES.CLIENTS PRIMARY KEY (CLIENT_ID)
        WITH SYNONYMS ('customers', 'accounts')
        COMMENT = 'Companies we sell to',
    opportunities AS SEMANTIC_DEMO.SALES.OPPORTUNITIES PRIMARY KEY (OPP_ID)
        WITH SYNONYMS ('deals', 'pipeline')
        COMMENT = 'Sales opportunities, each belonging to one client',
    revenue AS SEMANTIC_DEMO.SALES.REVENUE PRIMARY KEY (REV_ID)
        COMMENT = 'Actual revenue recognized for an opportunity',
    risks AS SEMANTIC_DEMO.SALES.RISKS PRIMARY KEY (RISK_ID)
        WITH SYNONYMS ('issues', 'concerns')
        COMMENT = 'Risks recorded against an opportunity'
)
RELATIONSHIPS (
    opportunity_client AS opportunities (CLIENT_ID) REFERENCES clients,
    revenue_opportunity AS revenue (OPP_ID) REFERENCES opportunities,
    risk_opportunity AS risks (OPP_ID) REFERENCES opportunities
)
FACTS (
    opportunities.opportunity_amount AS AMOUNT
        COMMENT = 'Expected value of the opportunity in USD',
    revenue.revenue_amount AS ACTUAL_REVENUE
        COMMENT = 'Revenue actually earned in USD'
)
DIMENSIONS (
    clients.client_id AS CLIENT_ID,
    clients.client_name AS CLIENT_NAME WITH SYNONYMS ('customer name', 'account name'),
    clients.industry AS INDUSTRY WITH SYNONYMS ('sector', 'vertical'),
    opportunities.opportunity_id AS OPP_ID,
    opportunities.opportunity_name AS OPP_NAME WITH SYNONYMS ('deal name', 'project'),
    risks.risk_level AS RISK_LEVEL WITH SYNONYMS ('severity', 'risk rating') 
        COMMENT = 'One of High, Medium or Low',
    risks.risk_description AS DESCRIPTION,
     opportunities.stage AS STAGE WITH SYNONYMS ('status', 'sales stage')
        COMMENT = 'One of Prospecting, Proposal, Negotiation, Closed Won or Closed Lost',
    opportunities.owner AS OWNER WITH SYNONYMS ('sales rep', 'account owner'),
    opportunities.created_date AS CREATED_DATE,
    opportunities.close_date AS CLOSE_DATE WITH SYNONYMS ('expected close date', 'closing date'),
    opportunities.close_month AS DATE_TRUNC('MONTH', CLOSE_DATE),
    opportunities.close_quarter AS DATE_TRUNC('QUARTER', CLOSE_DATE),
    opportunities.close_year AS YEAR(CLOSE_DATE)
)
METRICS (
    clients.client_count AS COUNT(CLIENT_ID),
    opportunities.total_pipeline AS SUM(AMOUNT) WITH SYNONYMS ('pipeline value', 'total deal value')
        COMMENT = 'Sum of expected opportunity amounts',
    opportunities.opportunity_count AS COUNT(OPP_ID) WITH SYNONYMS ('number of deals'),
    opportunities.average_deal_size AS AVG(AMOUNT),
    revenue.total_revenue AS SUM(ACTUAL_REVENUE) WITH SYNONYMS ('actual revenue', 'earned revenue'),
    risks.risk_count AS COUNT(RISK_ID),
    risks.high_risk_count AS COUNT_IF(UPPER(RISK_LEVEL) = 'HIGH'),
    revenue_to_pipeline_ratio AS DIV0(revenue.total_revenue, opportunities.total_pipeline)
        COMMENT = 'Share of expected pipeline that became actual revenue',
    opportunities.won_amount AS SUM(IFF(STAGE = 'Closed Won', AMOUNT, 0)) WITH SYNONYMS ('closed won value', 'won deals value'),
    opportunities.open_pipeline AS SUM(IFF(STAGE NOT IN ('Closed Won', 'Closed Lost'), AMOUNT, 0)) WITH SYNONYMS ('open pipeline', 'active pipeline')
        COMMENT = 'Value of opportunities that are not yet won or lost',
    opportunities.win_rate AS DIV0(COUNT_IF(STAGE = 'Closed Won'), COUNT_IF(STAGE IN ('Closed Won', 'Closed Lost')))
        COMMENT = 'Won opportunities divided by all closed opportunities'
)
COMMENT = 'Business semantic layer for client, opportunity, revenue and risk analysis along with owner and date dimensions';


GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON TABLE SEMANTIC_DEMO.SALES.REVENUE TO ROLE SNOWFLAKEIQ_ROLE;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC_DEMO.SALES.SV_SALES_ANALYTICS TO ROLE MCP_READER_ROLE;


