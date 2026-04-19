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
-- Create Customer Segments
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
-- Core RFM KPI Queries
-- =========================================================
-- Distribution of Customers in Each Segment
SELECT
    customer_segment,
    COUNT(*) AS customer_count
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY customer_count DESC;


-- Revenue by Segment
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    SUM(monetary) AS total_revenue,
    AVG(monetary) AS avg_revenue_per_customer
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- Customers by Segment Percentage
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2
    ) AS pct_of_customers
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY pct_of_customers DESC;


-- Revenue by Segment Percentage
SELECT
    customer_segment,
    SUM(monetary) AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2
    ) AS pct_of_total_revenue
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY pct_of_total_revenue DESC;


-- =========================================================
-- Segment Profile Analysis
-- =========================================================
-- Average RFM Values by Segment
SELECT
    customer_segment,
    ROUND(AVG(recency), 2) AS avg_recency,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary
FROM vw_customer_segments
GROUP BY customer_segment
ORDER BY avg_monetary DESC;


-- Top 10 customers in each Segment by Revenue
SELECT
	customer_segment,
	customer_id,
	monetary,
	frequency,
	recency
FROM(
	SELECT
		customer_segment,
		customer_id,
		monetary,
		frequency,
		recency,
		ROW_NUMBER() OVER(
						PARTITION BY customer_segment
						ORDER BY monetary DESC
						) AS rn
	FROM vw_customer_segments
)t
WHERE rn <= 10
ORDER BY customer_segment, monetary DESC


-- =========================================================
-- Segment Level Operational Queries
-- =========================================================
-- Champion
SELECT *
FROM vw_customer_segments
WHERE customer_segment = 'Champions'
ORDER BY monetary DESC;


-- Loyal Customers
SELECT *
FROM vw_customer_segments
WHERE customer_segment = 'Loyal Customers'
ORDER BY frequency DESC, monetary DESC;


-- Cannot Lose Them
SELECT *
FROM vw_customer_segments
WHERE customer_segment = 'Cannot Lose Them'
ORDER BY monetary DESC;


-- At Risk
SELECT *
FROM vw_customer_segments
WHERE customer_segment = 'At Risk'
ORDER BY recency DESC, monetary DESC;


-- =========================================================
-- Country Level Segmentation
-- =========================================================
SELECT
    b.country,
    s.customer_segment,
    COUNT(*) AS customer_count,
    SUM(s.monetary) AS segment_revenue
FROM vw_customer_segments s
JOIN (
    SELECT DISTINCT customer_id, country
    FROM vw_rfm_base
	) b
ON s.customer_id = b.customer_id
GROUP BY b.country, s.customer_segment
ORDER BY b.country, segment_revenue DESC;


























  
