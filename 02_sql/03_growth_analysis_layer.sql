-- ========================================================================
-- E-commerce Customer Analytics: Revenue Insights & Customer Segmentation
-- Growth Analysis Layer
-- ========================================================================
-- Purpose:
-- Build a clean growth analysis layer for monthly business performance
-- tracking from 2010 to 2011.
-- ========================================================================


-- =========================================================
-- Core Views
-- =========================================================
-- Monthly Growth KPI View
-- =========================================================
-- This is the base view for all trend, KPI, and comparison analysis.

-- Logic
-- - Revenue, orders, and units sold include all valid transactions
-- - Customer-based metrics only use known customer_id values
-- =========================================================
CREATE OR REPLACE VIEW vw_growth_metrics AS
SELECT
    DATE_TRUNC('month', invoice_date)::date AS month_start,
    EXTRACT(YEAR FROM invoice_date)::int AS year,
    EXTRACT(MONTH FROM invoice_date)::int AS month_num,
    TO_CHAR(DATE_TRUNC('month', invoice_date), 'YYYY-MM') AS year_month,

    -- -----------------------------------------------------
    -- Business performance metrics
    -- Include all valid transactions
    -- -----------------------------------------------------
    SUM(revenue) AS monthly_revenue,
    COUNT(DISTINCT invoice_number) AS total_orders,
    SUM(quantity) AS units_sold,
	ROUND(SUM(quantity) / NULLIF(COUNT(DISTINCT invoice_number), 0), 2) AS units_per_order,
	ROUND(SUM(revenue) / NULLIF(SUM(quantity), 0), 2) AS avg_selling_price,

    -- -----------------------------------------------------
    -- Customer metrics
    -- Known customers only
    -- -----------------------------------------------------
    COUNT(DISTINCT customer_id)
        FILTER (WHERE customer_id IS NOT NULL) AS active_customers,
	ROUND(SUM(revenue) / 
		  NULLIF(COUNT(DISTINCT invoice_number), 0), 2
    ) AS avg_order_value,
    ROUND(SUM(revenue) / 
		  NULLIF(COUNT(DISTINCT customer_id) FILTER (WHERE customer_id IS NOT NULL), 0), 2
    ) AS revenue_per_customer
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01'
GROUP BY
    DATE_TRUNC('month', invoice_date),
    EXTRACT(YEAR FROM invoice_date),
    EXTRACT(MONTH FROM invoice_date),
    TO_CHAR(DATE_TRUNC('month', invoice_date), 'YYYY-MM');


-- Yearly Summary
CREATE OR REPLACE VIEW vw_growth_kpis AS
WITH yearly_metrics AS (
    SELECT
        EXTRACT(YEAR FROM invoice_date)::int AS year,
        SUM(revenue) AS total_revenue,
        COUNT(DISTINCT invoice_number) AS total_orders,
        COUNT(DISTINCT customer_id)
            FILTER (WHERE customer_id IS NOT NULL) AS active_customers,
        ROUND(
            SUM(revenue) / NULLIF(COUNT(DISTINCT invoice_number), 0),
            2
        ) AS avg_order_value
    FROM vw_business_transactions
    WHERE invoice_date >= '2010-01-01'
      AND invoice_date < '2012-01-01'
    GROUP BY EXTRACT(YEAR FROM invoice_date)
)
SELECT
    year,
    total_revenue,
    total_orders,
    active_customers,
    avg_order_value,
    LAG(total_revenue) OVER (ORDER BY year) AS previous_year_revenue,
    ROUND(100.0 * (
            total_revenue - LAG(total_revenue) OVER (ORDER BY year)
        ) / NULLIF(LAG(total_revenue) OVER (ORDER BY year), 0), 2
    ) AS revenue_growth_pct,

    LAG(total_orders) OVER (ORDER BY year) AS previous_year_orders,
    ROUND(100.0 * (
            total_orders - LAG(total_orders) OVER (ORDER BY year)
        ) / NULLIF(LAG(total_orders) OVER (ORDER BY year), 0), 2
    ) AS orders_growth_pct,

    LAG(active_customers) OVER (ORDER BY year) AS previous_year_customers,
    ROUND(100.0 * (
            active_customers - LAG(active_customers) OVER (ORDER BY year)
        ) / NULLIF(LAG(active_customers) OVER (ORDER BY year), 0), 2
    ) AS customer_growth_pct,

    LAG(avg_order_value) OVER (ORDER BY year) AS previous_year_aov,
    ROUND(100.0 * (
            avg_order_value - LAG(avg_order_value) OVER (ORDER BY year)
        ) / NULLIF(LAG(avg_order_value) OVER (ORDER BY year), 0), 2
    ) AS aov_growth_pct
FROM yearly_metrics
ORDER BY year;


-- Monthly Presentation Layer
CREATE OR REPLACE VIEW vw_growth_dashboard AS
WITH base AS (
    SELECT
        month_start,
        year::int,
        month_num::int,
        TO_CHAR(month_start, 'Mon') AS month_name,
        year_month,
        monthly_revenue,
        total_orders,
        active_customers,
        avg_order_value
    FROM vw_growth_metrics
),
with_growth AS (
    SELECT
        month_start,
        year,
        month_num,
        month_name,
        year_month,
        monthly_revenue,
        total_orders,
        active_customers,
        avg_order_value,

        LAG(monthly_revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
        ROUND(100.0 * (
                monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_start)
            ) / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month_start), 0), 2
        ) AS mom_revenue_growth_pct,

        LAG(total_orders) OVER (ORDER BY month_start) AS previous_month_orders,
        ROUND(100.0 * (
                total_orders - LAG(total_orders) OVER (ORDER BY month_start)
            ) / NULLIF(LAG(total_orders) OVER (ORDER BY month_start), 0), 2
        ) AS mom_orders_growth_pct,

        LAG(active_customers) OVER (ORDER BY month_start) AS previous_month_customers,
        ROUND(100.0 * (
                active_customers - LAG(active_customers) OVER (ORDER BY month_start)
            ) / NULLIF(LAG(active_customers) OVER (ORDER BY month_start), 0), 2
        ) AS mom_customers_growth_pct,

        LAG(avg_order_value) OVER (ORDER BY month_start) AS previous_month_aov,
        ROUND(100.0 * (
                avg_order_value - LAG(avg_order_value) OVER (ORDER BY month_start)
            ) / NULLIF(LAG(avg_order_value) OVER (ORDER BY month_start), 0), 2
        ) AS mom_aov_growth_pct
    FROM base
)
SELECT
    month_start,
    year,
    month_num,
    month_name,
    year_month,
    monthly_revenue,
    total_orders,
    active_customers,
    avg_order_value,
    previous_month_revenue,
    mom_revenue_growth_pct,
    previous_month_orders,
    mom_orders_growth_pct,
    previous_month_customers,
    mom_customers_growth_pct,
    previous_month_aov,
    mom_aov_growth_pct,

    CASE WHEN year = 2010 THEN monthly_revenue END AS revenue_2010,
    CASE WHEN year = 2011 THEN monthly_revenue END AS revenue_2011,

    CASE WHEN year = 2010 THEN total_orders END AS orders_2010,
    CASE WHEN year = 2011 THEN total_orders END AS orders_2011,

    CASE WHEN year = 2010 THEN avg_order_value END AS aov_2010,
    CASE WHEN year = 2011 THEN avg_order_value END AS aov_2011
FROM with_growth
ORDER BY month_start;


-- =========================================================
-- Deep Dive Analysis Queries
-- =========================================================
-
-- =========================================================
-- Month-Over-Month Growth
-- =========================================================
-- Revenue
SELECT
    month_start,
    year_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month_start)) / 
				  NULLIF(LAG(monthly_revenue) OVER (ORDER BY month_start), 0), 2
    ) AS revenue_mom_growth_pct
FROM vw_growth_metrics
ORDER BY month_start;


-- Orders
SELECT
    month_start,
    year_month,
    total_orders,
    LAG(total_orders) OVER (ORDER BY month_start) AS previous_month_orders,
    ROUND(100.0 * 
				(total_orders - LAG(total_orders) OVER (ORDER BY month_start)) / 
				NULLIF(LAG(total_orders) OVER (ORDER BY month_start), 0), 2
    ) AS orders_mom_growth_pct
FROM vw_growth_metrics
ORDER BY month_start;


-- Active Customers (With Known Customer ID)
SELECT
    month_start,
    year_month,
    active_customers,
    LAG(active_customers) OVER (ORDER BY month_start) AS previous_month_customers,
    ROUND(100.0 * 
				(active_customers - LAG(active_customers) OVER (ORDER BY month_start)) / 
				NULLIF(LAG(active_customers) OVER (ORDER BY month_start), 0), 2
    ) AS active_customers_mom_growth_pct
FROM vw_growth_metrics
ORDER BY month_start;


-- Average Order Value 
SELECT
    month_start,
    year_month,
    avg_order_value,
    LAG(avg_order_value) OVER (ORDER BY month_start) AS previous_month_aov,
    ROUND(100.0 * 
				(avg_order_value - LAG(avg_order_value) OVER (ORDER BY month_start)) / 
				NULLIF(LAG(avg_order_value) OVER (ORDER BY month_start), 0), 2
    ) AS aov_mom_growth_pct
FROM vw_growth_metrics
ORDER BY month_start;


-- =========================================================
-- Monthly Year-Over-Year Trend Analysis
-- =========================================================
-- Revenue
SELECT
    month_num,
    TO_CHAR(TO_DATE(month_num::text, 'MM'), 'Mon') AS month_name,
    SUM(CASE WHEN year = 2010 THEN monthly_revenue END) AS revenue_2010,
    SUM(CASE WHEN year = 2011 THEN monthly_revenue END) AS revenue_2011,
    ROUND(
        100.0 * (
            SUM(CASE WHEN year = 2011 THEN monthly_revenue END)
            - SUM(CASE WHEN year = 2010 THEN monthly_revenue END)
        ) / NULLIF(SUM(CASE WHEN year = 2010 THEN monthly_revenue END), 0), 2
    ) AS yoy_revenue_growth_pct
FROM vw_growth_metrics
GROUP BY month_num
ORDER BY month_num;


-- Orders
SELECT
    month_num,
    TO_CHAR(TO_DATE(month_num::text, 'MM'), 'Mon') AS month_name,
    SUM(CASE WHEN year = 2010 THEN total_orders END) AS orders_2010,
    SUM(CASE WHEN year = 2011 THEN total_orders END) AS orders_2011,
    ROUND(
        100.0 * (
            SUM(CASE WHEN year = 2011 THEN total_orders END)
            - SUM(CASE WHEN year = 2010 THEN total_orders END)
        ) / NULLIF(SUM(CASE WHEN year = 2010 THEN total_orders END), 0), 2
    ) AS yoy_orders_growth_pct
FROM vw_growth_metrics
GROUP BY month_num
ORDER BY month_num;


-- Active Customers (Only Known Customers)
SELECT
    month_num,
    TO_CHAR(TO_DATE(month_num::text, 'MM'), 'Mon') AS month_name,
    SUM(CASE WHEN year = 2010 THEN active_customers END) AS customers_2010,
    SUM(CASE WHEN year = 2011 THEN active_customers END) AS customers_2011,
    ROUND(
        100.0 * (
            SUM(CASE WHEN year = 2011 THEN active_customers END)
            - SUM(CASE WHEN year = 2010 THEN active_customers END)
        ) / NULLIF(SUM(CASE WHEN year = 2010 THEN active_customers END), 0), 2
    ) AS yoy_customer_growth_pct
FROM vw_growth_metrics
GROUP BY month_num
ORDER BY month_num;


-- =========================================================
-- Annual KPI Summary (2010 vs 2011)
-- =========================================================
SELECT
    EXTRACT(YEAR FROM invoice_date) AS year,
    SUM(revenue) AS annual_revenue,
    COUNT(DISTINCT invoice_number) AS annual_orders,
    SUM(quantity) AS annual_units_sold,
    COUNT(DISTINCT customer_id)
        FILTER (WHERE customer_id IS NOT NULL) AS annual_active_customers,
    ROUND(SUM(revenue) / NULLIF(COUNT(DISTINCT invoice_number), 0), 2
    ) AS annual_avg_order_value
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01'
GROUP BY EXTRACT(YEAR FROM invoice_date)
ORDER BY year;


-- =========================================================
-- Annual Performance Comparison (2010 vs 2011)
-- =========================================================
-- Revenue
SELECT
    SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END) AS revenue_2010,
    SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) AS revenue_2011,
    ROUND(
        SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) -
        SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END), 2
    ) AS revenue_change,
    ROUND(100.0 * 
            (SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) -
            SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END)) / 
			NULLIF(SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END), 0), 2
    ) AS revenue_growth_pct
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01';


-- Orders
SELECT
    COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END) AS orders_2010,
    COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END) AS orders_2011,
    COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END) -
    COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END) AS orders_change,
    ROUND(100.0 * 
            (COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END) -
            COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END)) / 
			NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END), 0), 2
    ) AS orders_growth_pct
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01';


-- Active Customers
SELECT
    COUNT(DISTINCT CASE
        WHEN EXTRACT(YEAR FROM invoice_date) = 2010 AND customer_id IS NOT NULL
        THEN customer_id
    END) AS customers_2010,

    COUNT(DISTINCT CASE
        WHEN EXTRACT(YEAR FROM invoice_date) = 2011 AND customer_id IS NOT NULL
        THEN customer_id
    END) AS customers_2011,

    COUNT(DISTINCT CASE
        WHEN EXTRACT(YEAR FROM invoice_date) = 2011 AND customer_id IS NOT NULL
        THEN customer_id
    END) -
    COUNT(DISTINCT CASE
        WHEN EXTRACT(YEAR FROM invoice_date) = 2010 AND customer_id IS NOT NULL
        THEN customer_id
    END) AS customers_change,
    
	ROUND(100.0 * (COUNT(DISTINCT CASE
						WHEN EXTRACT(YEAR FROM invoice_date) = 2011 AND customer_id IS NOT NULL
						THEN customer_id END) 
					- COUNT(DISTINCT CASE
							WHEN EXTRACT(YEAR FROM invoice_date) = 2010 AND customer_id IS NOT NULL
							THEN customer_id END)) /
						NULLIF(
							COUNT(DISTINCT CASE
							WHEN EXTRACT(YEAR FROM invoice_date) = 2010 AND customer_id IS NOT NULL
							THEN customer_id END), 0), 2
    ) AS customers_growth_pct
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01';


-- Average Order Value
SELECT
    ROUND(
        SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END) /
        NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END), 0),
        2
    ) AS aov_2010,
    ROUND(
        SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) /
        NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END), 0),
        2
    ) AS aov_2011,
    ROUND(
        (
            SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) /
            NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END), 0)
        ) -
        (
            SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END) /
            NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END), 0)
        ),
        2
    ) AS aov_change,
    ROUND(
        100.0 * (
            (
                SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN revenue END) /
                NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2011 THEN invoice_number END), 0)
            ) -
            (
                SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END) /
                NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END), 0)
            )
        ) / NULLIF(
            (
                SUM(CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN revenue END) /
                NULLIF(COUNT(DISTINCT CASE WHEN EXTRACT(YEAR FROM invoice_date) = 2010 THEN invoice_number END), 0)
            ),
            0
        ),
        2
    ) AS aov_growth_pct
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01';


-- =========================================================
-- Segmented Growth Extensions
-- =========================================================
-- Bulk vs Regular Order Growth
CREATE OR REPLACE VIEW vw_growth_order_type_monthly AS
WITH order_monthly AS (
    SELECT
        DATE_TRUNC('month', invoice_date)::date AS month_start,
        invoice_id,
        SUM(quantity) AS total_quantity,
        SUM(revenue) AS order_revenue
    FROM vw_business_transactions
    WHERE invoice_date >= '2010-01-01'
      AND invoice_date < '2012-01-01'
    GROUP BY DATE_TRUNC('month', invoice_date), invoice_id
)
SELECT
    month_start,
    CASE
        WHEN total_quantity >= 50 THEN 'Bulk Order'
        ELSE 'Regular Order'
    END AS order_type,
    COUNT(*) AS total_orders,
    SUM(order_revenue) AS monthly_revenue,
    ROUND(AVG(order_revenue), 2) AS avg_order_value
FROM order_monthly
GROUP BY month_start, order_type
ORDER BY month_start, order_type;


SELECT
    month_start,
    order_type,
    total_orders,
    monthly_revenue,
    avg_order_value
FROM vw_growth_order_type_monthly
ORDER BY month_start, order_type;


-- Known vs Unknown Customer Growth
SELECT
    DATE_TRUNC('month', invoice_date)::date AS month_start,
    CASE
        WHEN customer_id IS NULL THEN 'Unknown'
        ELSE 'Known'
    END AS customer_visibility,
    SUM(revenue) AS monthly_revenue,
    COUNT(DISTINCT invoice_id) AS total_orders
FROM vw_business_transactions
WHERE invoice_date >= '2010-01-01'
  AND invoice_date < '2012-01-01'
GROUP BY
    DATE_TRUNC('month', invoice_date),
    CASE
        WHEN customer_id IS NULL THEN 'Unknown'
        ELSE 'Known'
    END
ORDER BY month_start, customer_visibility;


-- Wholesale vs Retail Customer Growth (Known Customers Only)
SELECT
    DATE_TRUNC('month', t.invoice_date)::date AS month_start,
    c.customer_type,
    SUM(t.revenue) AS monthly_revenue,
    COUNT(DISTINCT t.invoice_id) AS total_orders,
    COUNT(DISTINCT t.customer_id) AS active_customers
FROM vw_customer_transactions t
JOIN vw_customer_type c
    ON t.customer_id = c.customer_id
WHERE t.invoice_date >= '2010-01-01'
  AND t.invoice_date < '2012-01-01'
GROUP BY
    DATE_TRUNC('month', t.invoice_date),
    c.customer_type
ORDER BY month_start, c.customer_type;
