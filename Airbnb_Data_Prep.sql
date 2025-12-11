-- FILE: 1_Airbnb_Data_Prep_SQL.sql
-- PURPOSE: Advanced data modeling for Pricing and Operational Strategy

WITH Cleaned_Data AS (
    -- STEP 1: Cleaning and Basic Calculations
    SELECT
        listing_id,
        neighbourhood_cleansed,
        host_is_superhost,
        -- Clean and convert price column to numeric
        CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS NUMERIC) AS clean_price,
        CAST(availability_365 AS INTEGER) AS available_nights_per_year,
        -- Calculate Estimated Annual Revenue (EAR)
        (CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS NUMERIC) * 365 * 0.5) AS estimated_annual_revenue
    FROM
        raw_listings_table
    WHERE
        -- Data Quality: Filter out price outliers
        CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS NUMERIC) BETWEEN 50 AND 1000 
),

Neighborhood_Percentiles AS (
    -- STEP 2: Competitive Benchmarking (75th Percentile)
    SELECT
        neighbourhood_cleansed,
        -- Window Function: Finds the price higher than 75% of all prices in this neighborhood
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY clean_price) OVER (PARTITION BY neighbourhood_cleansed) AS p75_price,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY clean_price) OVER (PARTITION BY neighbourhood_cleansed) AS median_price
    FROM
        Cleaned_Data
)

-- FINAL REPORT 1: Competitive Pricing Analysis (Output for Pricing Strategy)
SELECT
    cd.neighbourhood_cleansed AS Neighbourhood,
    ROUND(AVG(cd.clean_price), 2) AS Average_Neighborhood_Price,
    ROUND(MAX(np.p75_price), 2) AS Competitive_Premium_Benchmark,
    ROUND(MAX(np.median_price), 2) AS Median_Market_Price,
    COUNT(cd.listing_id) AS Valid_Listing_Count
FROM
    Cleaned_Data cd
JOIN
    Neighborhood_Percentiles np
    ON cd.neighbourhood_cleansed = np.neighbourhood_cleansed
GROUP BY
    cd.neighbourhood_cleansed
HAVING
    COUNT(cd.listing_id) >= 20 
ORDER BY
    Competitive_Premium_Benchmark DESC;

-- FINAL REPORT 2: Host Performance & Efficiency Analysis (Output for Operational Strategy)
SELECT
    host_is_superhost AS Host_Status,
    COUNT(listing_id) AS Total_Listings_Count,
    
    ROUND(AVG(estimated_annual_revenue), 0) AS Avg_Estimated_Annual_Revenue,

    -- RevPAN: Average Revenue Per Available Night (Key Efficiency Metric)
    ROUND(SUM(estimated_annual_revenue) / SUM(available_nights_per_year), 2) AS Avg_Revenue_Per_Available_Night,

    ROUND(AVG(clean_price), 2) AS Average_Daily_Rate
FROM
    Cleaned_Data
GROUP BY
    host_is_superhost
ORDER BY
    Avg_Revenue_Per_Available_Night DESC;
