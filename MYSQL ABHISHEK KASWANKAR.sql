-- ============================================================
--  HIGH CLOUD AIRLINES
-- ============================================================

CREATE DATABASE IF NOT EXISTS AirlineAnalyticsDB;
USE AirlineAnalyticsDB;

-- ============================================================
-- STEP 1: TABLE CREATE & DATA IMPORT
-- ============================================================

DROP TABLE IF EXISTS flight_data;

CREATE TABLE flight_data (
    `Year`                   INT,
    `Month_Number`           INT,
    `Day`                    INT,
    `Date`                   DATE,
    `Month_Full_Name`        VARCHAR(20),
    `Quarter`                VARCHAR(5),
    `Year_Month`             VARCHAR(15),
    `Weekday_Number`         INT,
    `Weekday_Name`           VARCHAR(15),
    `Financial_Month`        INT,
    `Financial_Quarter`      VARCHAR(5),
    `Transported_Passengers` INT,
    `Available_Seats`        INT,
    `Load_Factor_Pct`        FLOAT,
    `Carrier_Name`           VARCHAR(150),
    `Origin_City`            VARCHAR(100),
    `Destination_City`       VARCHAR(100),
    `Distance`               INT,
    `Route`                  VARCHAR(250),
    `Day_Type`               VARCHAR(15),
    `Distance_Group_ID`      INT,
    `Distance_Interval`      VARCHAR(50)
);

-- ============================================================
-- HERE WE ARE LOADING DATA Book3_Cleaned.tsv is saved in following folder
-- C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/
-- ============================================================

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Book3_Cleaned.tsv'
INTO TABLE flight_data
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    `Year`,
    `Month_Number`,
    `Day`,
    @date_val,
    `Month_Full_Name`,
    `Quarter`,
    `Year_Month`,
    `Weekday_Number`,
    `Weekday_Name`,
    `Financial_Month`,
    `Financial_Quarter`,
    `Transported_Passengers`,
    `Available_Seats`,
    @load_factor,
    `Carrier_Name`,
    `Origin_City`,
    @dest_city,
    `Distance`,
    `Route`,
    `Day_Type`,
    `Distance_Group_ID`,
    `Distance_Interval`
)
SET
    `Date`              = STR_TO_DATE(@date_val, '%Y-%m-%d'),
    `Load_Factor_Pct`   = IF(@load_factor = '', NULL, @load_factor),
    `Destination_City`  = IF(@dest_city   = '', NULL, @dest_city);


-- ============================================================
-- KPI 1: CALENDAR TABLE
-- ============================================================

DROP TABLE IF EXISTS calendar_table;

CREATE TABLE calendar_table AS
SELECT DISTINCT
    `Year`,
    `Month_Number`,
    `Month_Full_Name`,
    `Quarter`,
    `Year_Month`,
    `Weekday_Number`,
    `Weekday_Name`,
    `Financial_Month`,
    `Financial_Quarter`
FROM flight_data
ORDER BY `Year`, `Month_Number`, `Weekday_Number`;

SELECT * FROM calendar_table LIMIT 15;


-- ============================================================
-- KPI 2A: LOAD FACTOR % - Yearly Basis  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds a Grand Total row where Year = NULL

SELECT
    COALESCE(CAST(`Year` AS CHAR), 'Grand Total')               AS `Year`,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)           AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)           AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                         AS Load_Factor_Pct
FROM flight_data
GROUP BY `Year` WITH ROLLUP
ORDER BY `Year`;


-- ============================================================
-- KPI 2B: LOAD FACTOR % - Quarterly Basis  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds subtotals per Year and a Grand Total row

SELECT
    COALESCE(CAST(`Year` AS CHAR), 'Grand Total')               AS `Year`,
    COALESCE(`Quarter`,            'Year Total')                 AS `Quarter`,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)           AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)           AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                         AS Load_Factor_Pct
FROM flight_data
GROUP BY `Year`, `Quarter` WITH ROLLUP
ORDER BY `Year`, `Quarter`;


-- ============================================================
-- KPI 2C: LOAD FACTOR % - Monthly Basis  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds subtotals per Year+Month, per Year, and a Grand Total row

SELECT
    COALESCE(CAST(`Year` AS CHAR),         'Grand Total')       AS `Year`,
    COALESCE(CAST(`Month_Number` AS CHAR), 'Year Total')        AS `Month_Number`,
    COALESCE(`Month_Full_Name`,            '')                   AS `Month_Full_Name`,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)           AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)           AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                         AS Load_Factor_Pct
FROM flight_data
GROUP BY `Year`, `Month_Number`, `Month_Full_Name` WITH ROLLUP
ORDER BY `Year`, `Month_Number`;


-- ============================================================
-- KPI 3: LOAD FACTOR % - Carrier Name Basis  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds a Grand Total row where Carrier_Name = NULL

SELECT
    COALESCE(`Carrier_Name`, 'Grand Total')                     AS `Carrier_Name`,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)           AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)           AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                         AS Load_Factor_Pct
FROM flight_data
GROUP BY `Carrier_Name` WITH ROLLUP
ORDER BY Load_Factor_Pct DESC;


-- ============================================================
-- KPI 4: TOP 10 CARRIER NAMES - Passenger Preference  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP over the top-10 subset gives a subtotal for those carriers only

SELECT
    COALESCE(`Carrier_Name`, 'Top-10 Total')                    AS `Carrier_Name`,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)           AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)           AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                         AS Load_Factor_Pct
FROM (
    -- Inner query first ranks carriers by total passengers
    -- Extra wrapper derived table (top10_names) bypasses MySQL Error 1235:
    -- "LIMIT & IN/ALL/ANY/SOME subquery" not supported directly
    SELECT
        fd.`Carrier_Name`,
        fd.`Transported_Passengers`,
        fd.`Available_Seats`
    FROM flight_data fd
    INNER JOIN (
        SELECT `Carrier_Name`
        FROM (
            SELECT `Carrier_Name`
            FROM flight_data
            GROUP BY `Carrier_Name`
            ORDER BY SUM(`Transported_Passengers`) DESC
            LIMIT 10
        ) AS top10_names
    ) AS top10_filter
      ON fd.`Carrier_Name` = top10_filter.`Carrier_Name`
) AS top10
GROUP BY `Carrier_Name` WITH ROLLUP
ORDER BY Total_Passengers_M DESC;


-- ============================================================
-- KPI 5: TOP 20 ROUTES - Based on Number of Flights  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds a Grand Total row (Route = NULL) for the top-20 subset

SELECT
    COALESCE(`Route`,            'Top-20 Total')                AS `Route`,
    COALESCE(`Origin_City`,      '')                            AS `Origin_City`,
    COALESCE(`Destination_City`, '')                            AS `Destination_City`,
    COUNT(*)                                                    AS Number_of_Flights,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)          AS Total_Passengers_M
FROM (
    -- Inner query isolates the top-20 routes first
    -- Extra wrapper derived table (top20_routes) bypasses MySQL Error 1235:
    -- "LIMIT & IN/ALL/ANY/SOME subquery" not supported directly
    SELECT
        fd.`Route`,
        fd.`Origin_City`,
        fd.`Destination_City`,
        fd.`Transported_Passengers`
    FROM flight_data fd
    INNER JOIN (
        SELECT `Route`
        FROM (
            SELECT `Route`
            FROM flight_data
            WHERE `Destination_City` IS NOT NULL
            GROUP BY `Route`
            ORDER BY COUNT(*) DESC
            LIMIT 20
        ) AS top20_routes
    ) AS top20_filter
      ON fd.`Route` = top20_filter.`Route`
    WHERE fd.`Destination_City` IS NOT NULL
) AS top20
GROUP BY `Route`, `Origin_City`, `Destination_City` WITH ROLLUP
ORDER BY Number_of_Flights DESC;


-- ============================================================
-- KPI 6A: LOAD FACTOR - Weekend vs Weekday  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds a Grand Total row where Day_Type = NULL

SELECT
    COALESCE(`Day_Type`, 'Grand Total')                         AS `Day_Type`,
    COUNT(*)                                                    AS Number_of_Flights,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)          AS Total_Passengers_M,
    ROUND(SUM(`Available_Seats`)        / 1000000, 2)          AS Total_Seats_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                        AS Load_Factor_Pct
FROM flight_data
GROUP BY `Day_Type` WITH ROLLUP
ORDER BY Load_Factor_Pct DESC;


-- ============================================================
-- KPI 6B: LOAD FACTOR - Day-wise Breakdown (Mon to Sun)  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds subtotals per Weekday+DayType and a Grand Total row

SELECT
    COALESCE(CAST(`Weekday_Number` AS CHAR), 'Grand Total')     AS `Weekday_Number`,
    COALESCE(`Weekday_Name`, 'All Days')                        AS `Weekday_Name`,
    COALESCE(`Day_Type`,     '')                                AS `Day_Type`,
    COUNT(*)                                                    AS Number_of_Flights,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)          AS Total_Passengers_M,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                        AS Load_Factor_Pct
FROM flight_data
GROUP BY `Weekday_Number`, `Weekday_Name`, `Day_Type` WITH ROLLUP
ORDER BY `Weekday_Number`;


-- ============================================================
-- KPI 7: NUMBER OF FLIGHTS - Distance Group Basis  [WITH ROLLUP | Values in Millions]
-- ============================================================
-- ROLLUP adds subtotals per Distance Group and a Grand Total row

SELECT
    COALESCE(CAST(`Distance_Group_ID` AS CHAR), 'Grand Total') AS `Distance_Group_ID`,
    COALESCE(`Distance_Interval`, 'All Intervals')             AS `Distance_Interval`,
    COUNT(*)                                                   AS Number_of_Flights,
    ROUND(SUM(`Transported_Passengers`) / 1000000, 2)         AS Total_Passengers_M,
    ROUND(AVG(`Distance`), 0)                                  AS Avg_Distance_Miles,
    ROUND(
        SUM(`Transported_Passengers`) / NULLIF(SUM(`Available_Seats`), 0) * 100
    , 2)                                                       AS Load_Factor_Pct
FROM flight_data
GROUP BY `Distance_Group_ID`, `Distance_Interval` WITH ROLLUP
ORDER BY `Distance_Group_ID`;
