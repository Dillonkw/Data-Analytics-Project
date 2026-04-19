-- =========================================================
-- E-commerce Customer Analytics: Revenue Insights & Customer Segmentation
-- Customer Analysis Layer
-- =========================================================
-- Purpose:
-- Build a customer-focused analysis layer for identifying
-- customer value, purchase behavior, and revenue concentration.
-- =========================================================


-- =========================================================
-- Customer Analysis View
-- =========================================================
-- Logic:
-- - Exclude cancellations
-- - Exclude adjustments
-- - Exclude non-positive quantity
-- - Exclude non-positive price
-- - Keep only known customers
-- =========================================================
CREATE OR REPLACE VIEW vw_customer_transactions AS
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
  AND price > 0
  AND customer_id IS NOT NULL;


-- =========================================================
-- Customer Summary Table/View
-- =========================================================
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    customer_id,
    MIN(invoice_date) AS first_purchase_date,
    MAX(invoice_date) AS last_purchase_date,
    COUNT(DISTINCT invoice_id) AS total_orders,
    SUM(quantity) AS total_units,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_transaction_revenue,
    SUM(revenue) / COUNT(DISTINCT invoice_id) AS avg_order_value
FROM vw_customer_transactions
GROUP BY customer_id;


-- =========================================================
-- Core Customer KPI Queries
-- =========================================================
-- Total Known Customers
SELECT
	COUNT(*) AS total_known_customers
FROM vw_customer_summary;


-- Average Revenue Per Customer
SELECT
	AVG(total_revenue) AS avg_revenue_per_customer
FROM vw_customer_summary;


-- Median Revenue Per Customer
SELECT
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_revenue_per_customer
FROM vw_customer_summary;


-- Average Orders Per Customer
SELECT
	AVG(total_orders) AS avg_orders_per_customer
FROM vw_customer_summary;


-- Average Customer Lifetime Value
SELECT
	AVG(total_revenue) AS customer_lifetime_value
FROM vw_customer_summary;


-- =========================================================
-- Top Customer Queries
-- =========================================================
--Top 10 Customers by Revenue
SELECT
    customer_id,
    total_orders,
    total_units,
    total_revenue,
    avg_order_value,
    first_purchase_date,
    last_purchase_date
FROM vw_customer_summary
ORDER BY total_revenue DESC
LIMIT 10;

-- Top 10 Customers by Number of Orders
SELECT
	customer_id,
	total_orders,
	total_revenue,
	avg_order_value
FROM vw_customer_summary
ORDER BY total_orders DESC, total_revenue DESC
LIMIT 10;


-- =========================================================
-- Revenue Concentration / Pareto Analysis
-- =========================================================
-- Revenue by Customer Decile
WITH ranked_customers AS (
    SELECT
        customer_id,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM vw_customer_summary
)
SELECT
    revenue_decile,
    COUNT(*) AS customers_in_decile,
    SUM(total_revenue) AS decile_revenue,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2
	) AS pct_of_total_revenue
FROM ranked_customers
GROUP BY revenue_decile
ORDER BY revenue_decile;


-- Top 10% Customer Revenue Contribution
WITH ranked_customers AS (
    SELECT
        customer_id,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM vw_customer_summary
)
SELECT
    SUM(total_revenue) AS top_10pct_revenue,
    ROUND(100.0 * SUM(total_revenue) / 
	(SELECT SUM(total_revenue) FROM vw_customer_summary), 2
    ) AS pct_of_total_revenue
FROM ranked_customers
WHERE revenue_decile = 1;


-- =========================================================
-- Customer Distribution Analysis
-- =========================================================
-- Revenue Distribution Buckets
SELECT
    CASE
        WHEN total_revenue < 100 THEN 'Under 100'
        WHEN total_revenue < 500 THEN '100-499'
        WHEN total_revenue < 1000 THEN '500-999'
        WHEN total_revenue < 5000 THEN '1,000-4,999'
        ELSE '5,000+'
    END AS revenue_bucket,
    COUNT(*) AS customer_count,
    SUM(total_revenue) AS bucket_revenue
FROM vw_customer_summary
GROUP BY revenue_bucket
ORDER BY bucket_revenue DESC;


-- Order Frequency Distribution
SELECT
    CASE
        WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders BETWEEN 2 AND 3 THEN '2-3 orders'
        WHEN total_orders BETWEEN 4 AND 5 THEN '4-5 orders'
        WHEN total_orders BETWEEN 6 AND 10 THEN '6-10 orders'
        ELSE '11+ orders'
    END AS order_bucket,
    COUNT(*) AS customer_count
FROM vw_customer_summary
GROUP BY order_bucket
ORDER BY customer_count DESC;


-- =========================================================
-- Recency / Activity Analysis
-- =========================================================
-- Days Since Last Purchase Relative To Dataset Max Date
WITH date_reference AS (
    SELECT 
		MAX(invoice_date)::date AS max_date
    FROM vw_customer_transactions
)
SELECT
    c.customer_id,
    c.last_purchase_date::date AS last_purchase_date,
    (d.max_date - c.last_purchase_date::date) AS days_since_last_purchase,
    c.total_orders,
    c.total_revenue
FROM vw_customer_summary c
CROSS JOIN date_reference d
ORDER BY days_since_last_purchase DESC;


-- Active vs Inactive Customer Buckets
WITH date_reference AS (
    SELECT 
		MAX(invoice_date)::date AS max_date
    FROM vw_customer_transactions
),
customer_activity AS (
    SELECT
        c.customer_id,
        (d.max_date - c.last_purchase_date::date) AS days_since_last_purchase
    FROM vw_customer_summary c
    CROSS JOIN date_reference d
)
SELECT
    CASE
        WHEN days_since_last_purchase <= 30 THEN 'Active: 0-30 days'
        WHEN days_since_last_purchase <= 90 THEN 'Warm: 31-90 days'
        WHEN days_since_last_purchase <= 180 THEN 'At Risk: 91-180 days'
        ELSE 'Inactive: 181+ days'
    END AS activity_segment,
    COUNT(*) AS customer_count
FROM customer_activity
GROUP BY activity_segment
ORDER BY customer_count DESC;


-- =========================================================
-- Geographic Customer Analysis
-- =========================================================
-- Country Performance in Terms of Customers and Value
SELECT
    country,
    COUNT(DISTINCT customer_id) AS customer_count,
    SUM(revenue) AS total_revenue,
    SUM(revenue) / COUNT(DISTINCT customer_id) AS revenue_per_customer
FROM vw_customer_transactions
GROUP BY country
ORDER BY total_revenue DESC;


-- Top Countries by Customer Count
SELECT
    country,
    COUNT(DISTINCT customer_id) AS customer_count
FROM vw_customer_transactions
GROUP BY country
ORDER BY customer_count DESC
LIMIT 10;

















