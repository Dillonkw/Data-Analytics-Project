-- ========================================================================
-- E-commerce Customer Analytics: Revenue Insights & Customer Segmentation
-- Business Overview Layer
-- ========================================================================
-- Purpose:
-- Create a clean view for the business overview and the core queries
-- needed for an executive dashboard.
-- =========================================================


-- =========================================================
-- Business Overview View
-- =========================================================
-- This view keeps only valid sales transactions for business
-- performance reporting, while preserving transactions with
-- unknown customers.

-- Logic:
-- Exclude cancellations
-- Exclude adjustments
-- Exclude non-positive quantity
-- Exclude non-positive price
-- Keep all customer IDs, including NULL customer_id values
-- =========================================================
CREATE OR REPLACE VIEW vw_business_transactions AS
SELECT
    invoice_number,
    product_code,
    product_description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    is_cancelled,
    is_adjustment,
    invoice_id,
    transaction_type,
    base_product_code,
    product_variant,
    is_valid_product,
    revenue
FROM retail_cleaned
WHERE is_cancelled = FALSE
  AND is_adjustment = FALSE
  AND quantity > 0
  AND price > 0;


-- =========================================================
-- Core KPI Queries
-- =========================================================
-- Sales Revenue
SELECT
	SUM(revenue) AS sales_revenue
FROM vw_business_transactions;


-- Total Orders
SELECT
	COUNT(DISTINCT invoice_number) AS total_orders
FROM vw_business_transactions;


--Total Customers
SELECT
	COUNT(DISTINCT customer_id) AS total_customers
FROM vw_business_transactions
WHERE customer_id IS NOT NULL;


-- Average Order Value
SELECT
	SUM(revenue) / COUNT(DISTINCT invoice_id) AS average_order_value
FROM vw_business_transactions


-- Median Order Value
WITH order_totals AS (
    SELECT
        invoice_id,
        SUM(revenue) AS order_value
    FROM vw_business_transactions
    GROUP BY invoice_id
)
SELECT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value) AS median_order_value
FROM order_totals;


-- Net Revenue
SELECT
	SUM(revenue) AS net_revenue
FROM retail_cleaned;


-- Adjustment Impact
SELECT
	SUM(revenue) AS adjustment_impact
FROM retail_cleaned
WHERE is_adjustment = TRUE;


-- Cancellation Impact
SELECT
	SUM(revenue) AS cancellation_impact
FROM retail_cleaned
WHERE is_cancelled = TRUE;


-- =========================================================
-- Time-Based Performance Queries
-- =========================================================
-- Monthly Revenue Trend
SELECT
	SUM(revenue) AS sales_revenue,
	DATE_TRUNC('month', invoice_date) AS month
FROM vw_business_transactions
GROUP BY month
ORDER BY month;


-- Monthly Order Trend
SELECT
	COUNT(DISTINCT invoice_id) AS total_orders,
	DATE_TRUNC('month', invoice_date) AS month
FROM vw_business_transactions
GROUP BY month
ORDER BY month;


-- Yearly Revenue Trend
SELECT
	SUM(revenue) AS revenue,
	DATE_TRUNC('year', invoice_date) AS year
FROM vw_business_transactions
GROUP BY year
ORDER BY year;


-- Monthly Growth Rate
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', invoice_date) AS month,
        SUM(revenue) AS revenue
    FROM vw_business_transactions
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
   ROUND(
    ((revenue - LAG(revenue) OVER (ORDER BY month))
	/ NULLIF(LAG(revenue) OVER (ORDER BY month), 0)
    ) * 100, 2) AS growth_rate_pct
FROM monthly_revenue
ORDER BY month;


-- =========================================================
-- Revenue Driver Queries
-- =========================================================

-- Revenue by Country
SELECT
	country,
	SUM(revenue) AS sales_revenue
FROM vw_business_transactions
GROUP BY country
ORDER BY sales_revenue DESC;


-- Top 10 Products by Revenue
SELECT
	product_description,
	SUM(revenue) AS sales_revenue
FROM vw_business_transactions
WHERE is_valid_product = TRUE
GROUP BY product_description
ORDER BY sales_revenue DESC
LIMIT 10
















