CREATE TABLE retail.retail_cleaned (
    invoice_number text,
    product_code text,
    product_description text,
    quantity integer,
    invoice_date timestamp,
    price numeric(12,2),
    customer_id bigint,
    country text,
    is_cancelled boolean,
    is_adjustment boolean,
    invoice_id text,
    transaction_type text,
    base_product_code text,
    product_variant text,
    is_valid_product boolean,
    revenue numeric(14,2)
);

-- Checks to ensure data loaded in properly
SELECT COUNT(*) FROM retail.retail_cleaned;

SELECT * FROM retail.retail_cleaned LIMIT 10;

SELECT
    COUNT(*) FILTER (WHERE invoice_number IS NULL) AS missing_invoice_number,
    COUNT(*) FILTER (WHERE invoice_date IS NULL) AS missing_invoice_date,
    COUNT(*) FILTER (WHERE price IS NULL) AS missing_price
FROM retail.retail_cleaned;



