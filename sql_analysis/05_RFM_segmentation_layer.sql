-- =========================================================
-- E-commerce Customer Analytics: Revenue Insights & Customer Segmentation
-- RFM Segmentation Layer 
-- =========================================================
-- Purpose:
-- Build an RFM segmentation layer for customer strategy.
--
-- RFM Definitions:
-- - Recency: How recently a customer purchased
-- - Frequency: How often a customer purchased
-- - Monetary: How much revenue a customer generated
-- =========================================================


-- =========================================================
-- Create RFM Base View
-- =========================================================
-- Logic:
-- - Exclude cancellations
-- - Exclude adjustments
-- - Exclude non-positive quantity
-- - Exclude non-positive price
-- - Keep only known customers
-- =========================================================
-- This view uses only valid customer purchases.
CREATE OR REPLACE VIEW vw_rfm_base AS
SELECT
    invoice_number,
    product_code,
    product_description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country,
    invoice_id,
    revenue
FROM retail_cleaned
WHERE is_cancelled = FALSE
  AND is_adjustment = FALSE
  AND quantity > 0
  AND price > 0
  AND customer_id IS NOT NULL;


-- =========================================================
-- Create Raw RFM Table
-- =========================================================
-- Recency is measured relative to the day after the latest
-- transaction date in the dataset.
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH date_reference AS (
    SELECT 
		MAX(invoice_date)::date + INTERVAL '1 day' AS reference_date
    FROM vw_rfm_base
),
rfm_base AS (
    SELECT
        customer_id,
        MAX(invoice_date)::date AS last_purchase_date,
        COUNT(DISTINCT invoice_id) AS frequency,
        SUM(revenue) AS monetary
    FROM vw_rfm_base
    GROUP BY customer_id
)
SELECT
    r.customer_id,
    (d.reference_date::date - r.last_purchase_date) AS recency,
    r.frequency,
    r.monetary
FROM rfm_base r
CROSS JOIN date_reference d;


-- =========================================================
-- 3. Create RFM Scores
-- =========================================================
-- Recency:
-- Lower recency is better
--
-- Frequency:
-- Higher frequency is better
--
-- Monetary:
-- Higher monetary is better
CREATE OR REPLACE VIEW vw_customer_rfm_scores AS
WITH scored AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM vw_customer_rfm
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score
FROM scored;

-- =========================================================
-- Create Detailed Customer Segments
-- =========================================================
-- Segment logic can be adjusted
CREATE OR REPLACE VIEW vw_customer_segments AS
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    rfm_score,
    CASE
	    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
	    WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal Customers'
	    WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
	    WHEN r_score = 3 AND f_score = 3 THEN 'Potential Loyalists'
	    WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
	    WHEN r_score <= 2 AND m_score >= 4 THEN 'Cannot Lose Them'
	    WHEN r_score = 1 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
	    ELSE 'Needs Attention'
	END AS customer_segment
FROM vw_customer_rfm_scores;


-- =========================================================
-- Enhanced RFM With Customer Type
-- =========================================================
-- Requires:
-- vw_customer_type

-- This connects RFM strategy to the wholesale vs retail
-- customer classification built in the customer analysis layer.
-- =========================================================
CREATE OR REPLACE VIEW vw_rfm_enhanced AS
SELECT
    s.customer_id,
    t.customer_type,
    s.recency,
    s.frequency,
    s.monetary,
    s.r_score,
    s.f_score,
    s.m_score,
    s.rfm_score,
    s.customer_segment
FROM vw_customer_segments s
LEFT JOIN vw_customer_type t
    ON s.customer_id = t.customer_id;

-- =========================================================
-- Strategic RFM Segment Grouping
-- =========================================================
-- Purpose:
-- Simplify RFM segments into groups for shareholders

-- Grouping logic:
-- High Value = best existing customers
-- Growth Opportunity = newer or developing customers
-- At Risk = retention priority
-- Lost = win-back / deprioritize depending on value
-- =========================================================
CREATE OR REPLACE VIEW vw_rfm_segment_groups AS
SELECT
    customer_id,
    customer_type,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    rfm_score,
    customer_segment,
    CASE
        WHEN customer_segment IN ('Champions', 'Loyal Customers')
            THEN 'High Value'
        WHEN customer_segment IN ('Potential Loyalists', 'Recent Customers')
            THEN 'Growth Opportunity'
        WHEN customer_segment IN ('At Risk', 'Cannot Lose Them', 'Needs Attention')
            THEN 'At Risk'
        WHEN customer_segment = 'Lost'
            THEN 'Lost'
        ELSE 'Other'
    END AS segment_group
FROM vw_rfm_enhanced;

-- =========================================================
-- Core RFM KPI Queries
-- =========================================================
-- Distribution of Customers in Each Detailed Segment
SELECT
    customer_segment,
    COUNT(*) AS customer_count
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY customer_count DESC;


-- Revenue by Detailed Segment
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    SUM(monetary) AS total_revenue
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- Customers by Detailed Segment Percentage
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2
    ) AS pct_of_customers
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY pct_of_customers DESC;


-- Revenue by Detailed Segment Percentage
SELECT
    customer_segment,
    SUM(monetary) AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2
    ) AS pct_of_total_revenue
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY pct_of_total_revenue DESC;


-- =========================================================
-- Enhanced RFM Analysis by Customer Type
-- =========================================================
-- Segment Distribution by Customer Type
SELECT
    customer_segment,
    customer_type,
    COUNT(*) AS customer_count
FROM vw_rfm_enhanced
GROUP BY customer_segment, customer_type
ORDER BY customer_segment, customer_count DESC;


-- Revenue by Segment and Customer Type
SELECT
    customer_segment,
    customer_type,
    COUNT(*) AS customers,
    SUM(monetary) AS total_revenue,
    ROUND(AVG(monetary), 2) AS avg_revenue_per_customer,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2
    ) AS pct_total_revenue
FROM vw_rfm_enhanced
GROUP BY customer_segment, customer_type
ORDER BY total_revenue DESC;


-- Average Segment Profile by Customer Type
SELECT
    customer_segment,
    customer_type,
    ROUND(AVG(monetary), 2) AS avg_revenue,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(recency), 2) AS avg_recency
FROM vw_rfm_enhanced
GROUP BY customer_segment, customer_type
ORDER BY avg_revenue DESC;


-- Top At-Risk High-Value Customers
SELECT
    customer_id,
    customer_type,
    customer_segment,
    monetary,
    frequency,
    recency
FROM vw_rfm_enhanced
WHERE customer_segment IN ('At Risk', 'Cannot Lose Them')
ORDER BY monetary DESC
LIMIT 20;


-- =========================================================
-- Strategic Segment Group Queries
-- =========================================================
-- Strategic Group Distribution
SELECT
    segment_group,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM vw_rfm_segment_groups
GROUP BY segment_group
ORDER BY customer_count DESC;


-- Strategic Group Revenue Summary
SELECT
    segment_group,
    COUNT(*) AS customers,
    SUM(monetary) AS total_revenue,
    ROUND(AVG(monetary), 2) AS avg_revenue_per_customer,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_of_revenue
FROM vw_rfm_segment_groups
GROUP BY segment_group
ORDER BY total_revenue DESC;


-- Strategic Group by Customer Type
SELECT
    segment_group,
    customer_type,
    COUNT(*) AS customers,
    SUM(monetary) AS revenue,
    ROUND(AVG(monetary), 2) AS avg_revenue_per_customer,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2
    ) AS pct_total_revenue
FROM vw_rfm_segment_groups
GROUP BY segment_group, customer_type
ORDER BY revenue DESC;


-- Strategic group profile
SELECT
    segment_group,
    customer_type,
    ROUND(AVG(recency), 2) AS avg_recency,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary
FROM vw_rfm_segment_groups
GROUP BY segment_group, customer_type
ORDER BY avg_monetary DESC;


-- =========================================================
-- Strategic Action Strategy
-- =========================================================
SELECT
    segment_group,
    customer_type,
    COUNT(*) AS customers,
    SUM(monetary) AS revenue,
    CASE
        WHEN segment_group = 'High Value' THEN 'Reward, retain, and upsell'
        WHEN segment_group = 'Growth Opportunity' THEN 'Nurture and convert to loyal'
        WHEN segment_group = 'At Risk' THEN 'Target with retention campaigns'
        WHEN segment_group = 'Lost' THEN 'Test win-back selectively'
        ELSE 'Monitor'
    END AS strategy
FROM vw_rfm_segment_groups
GROUP BY segment_group, customer_type
ORDER BY revenue DESC;

