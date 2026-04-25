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
-- Customer Type Classification View
-- =========================================================
CREATE OR REPLACE VIEW vw_customer_type AS
WITH order_totals AS (
    SELECT
        customer_id,
        invoice_id,
        SUM(quantity) AS order_quantity,
        SUM(revenue) AS order_revenue
    FROM vw_customer_transactions
    GROUP BY customer_id, invoice_id
),
customer_order_profile AS (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        AVG(order_quantity) AS avg_order_quantity,
        MAX(order_quantity) AS max_order_quantity,
        AVG(order_revenue) AS avg_order_value,
        SUM(CASE WHEN order_quantity >= 50 THEN 1 ELSE 0 END) AS bulk_orders
    FROM order_totals
    GROUP BY customer_id
)
SELECT
    customer_id,
    total_orders,
    ROUND(avg_order_quantity, 2) AS avg_order_quantity,
    max_order_quantity,
    ROUND(avg_order_value, 2) AS avg_order_value,
    bulk_orders,
    ROUND(100.0 * bulk_orders / NULLIF(total_orders, 0), 2) AS pct_bulk_orders,
    CASE
        WHEN bulk_orders >= 2 THEN 'Wholesale'
        WHEN avg_order_quantity >= 50 THEN 'Wholesale'
        ELSE 'Retail'
    END AS customer_type
FROM customer_order_profile;

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
-- Enhanced Customer Summary View
-- =========================================================
CREATE OR REPLACE VIEW vw_customer_summary_enhanced AS
SELECT
    s.customer_id,
    t.customer_type,
    t.total_orders AS classified_total_orders,
    t.avg_order_quantity,
    t.max_order_quantity,
    t.bulk_orders,
    t.pct_bulk_orders,
    s.first_purchase_date,
    s.last_purchase_date,
    s.total_orders,
    s.total_units,
    s.total_revenue,
    s.avg_transaction_revenue,
    s.avg_order_value
FROM vw_customer_summary s
LEFT JOIN vw_customer_type t
    ON s.customer_id = t.customer_id;


-- =========================================================
-- Core Customer KPI Queries
-- =========================================================
-- Total Known Customers
SELECT
	COUNT(*) AS total_known_customers
FROM vw_customer_summary;


-- Total Know Customer Revenue
SELECT
    SUM(total_revenue) AS total_customer_revenue
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


-- =========================================================
-- Customer Type Comparison Queries
-- =========================================================
-- Customer Count by Type
SELECT
    customer_type,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM vw_customer_summary_enhanced
GROUP BY customer_type
ORDER BY customer_count DESC;


-- Revenue by Type
SELECT
    customer_type,
    COUNT(*) AS customer_count,
    SUM(total_revenue) AS total_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_customer,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS pct_of_total_revenue
FROM vw_customer_summary_enhanced
GROUP BY customer_type
ORDER BY total_revenue DESC;


-- Orders and Units by Type
SELECT
    customer_type,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_units), 2) AS avg_units_per_customer,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM vw_customer_summary_enhanced
GROUP BY customer_type
ORDER BY avg_order_value DESC;


-- Customer Lifetime Value
SELECT
    customer_type,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_revenue), 2) AS avg_clv,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_clv,
    MAX(total_revenue) AS max_clv
FROM vw_customer_summary_enhanced
GROUP BY customer_type
ORDER BY avg_clv DESC;


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


-- Top 10% of Customers Distribution by Customer Type
WITH ranked_customers AS (
    SELECT
        customer_id,
        customer_type,
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM vw_customer_summary_enhanced
)
SELECT
    customer_type,
    COUNT(*) AS customers,
    SUM(total_revenue) AS total_revenue
FROM ranked_customers
WHERE revenue_decile = 1
GROUP BY customer_type
ORDER BY total_revenue DESC;


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


-- Revenue buckets by Customer Type
SELECT
    customer_type,
    CASE
        WHEN total_revenue < 100 THEN 'Under 100'
        WHEN total_revenue < 500 THEN '100-499'
        WHEN total_revenue < 1000 THEN '500-999'
        WHEN total_revenue < 5000 THEN '1,000-4,999'
        ELSE '5,000+'
    END AS revenue_bucket,
    COUNT(*) AS customer_count,
    SUM(total_revenue) AS bucket_revenue
FROM vw_customer_summary_enhanced
GROUP BY customer_type, revenue_bucket
ORDER BY customer_type, bucket_revenue DESC;


-- Order Frequency by Customer Type
SELECT
    customer_type,
    CASE
        WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders BETWEEN 2 AND 3 THEN '2-3 orders'
        WHEN total_orders BETWEEN 4 AND 5 THEN '4-5 orders'
        WHEN total_orders BETWEEN 6 AND 10 THEN '6-10 orders'
        ELSE '11+ orders'
    END AS order_bucket,
    COUNT(*) AS customer_count
FROM vw_customer_summary_enhanced
GROUP BY customer_type, order_bucket
ORDER BY customer_type, customer_count DESC;


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
