#%%
# ============================================
# Online Retail - Data Cleaning Pipeline
# ============================================

import pandas as pd
import numpy as np

#%%
# ============================================
# 1. Helper function for validation
# ============================================
def validate_df(df, name="Dataset"):
    """
    Print a quick validation summary for the dataframe.
    Useful for checking the impact of each cleaning step.
    """
    print(f"\n--- {name} ---")
    print("Shape:", df.shape)
    print("\nMissing values:")
    print(df.isnull().sum())
    print("\nDuplicate rows:", df.duplicated().sum())
    print("Negative quantities:", (df["quantity"] < 0).sum())
    print("Negative prices:", (df["price"] < 0).sum())
    print("Unique invoices:", df["invoice_number"].nunique())

#%%
# ============================================
# 2. Load and combine the raw Excel sheets
# ============================================
file = "online_retail_II.xlsx"

df1 = pd.read_excel(file, sheet_name=0)
df2 = pd.read_excel(file, sheet_name=1)

# Combine both sheets into one dataset
df = pd.concat([df1, df2], ignore_index=True)

## Initial inspection of the combined raw dataset
print("Combined shape:", df.shape)
print(df.head())


# %%
# ============================================
# 3. Rename columns
# ============================================
# Rename columns to snake_case for consistency and SQL compatibility
df = df.rename(columns={
    "Invoice": "invoice_number",
    "StockCode": "product_code",
    "Description": "product_description",
    "Quantity": "quantity",
    "InvoiceDate": "invoice_date",
    "Price": "price",
    "Customer ID": "customer_id",
    "Country": "country"
})

#%%
# ============================================
# 4. Validate raw structure after renaming
# ============================================
validate_df(df, "Raw Data")
#%%
# ============================================
# 5. Fix data types
# ============================================
# Convert columns to appropriate types for cleaning and analysis
df["invoice_number"] = df["invoice_number"].astype("string")
df["product_code"] = df["product_code"].astype("string")
df["product_description"] = df["product_description"].astype("string")
df["country"] = df["country"].astype("string")
df["invoice_date"] = pd.to_datetime(df["invoice_date"])
df["customer_id"] = df["customer_id"].astype("Int64")

validate_df(df, "After Type Fixes")
print("\nData types:")
print(df.dtypes)
#%%
# ============================================
# 6. Standardize text formatting
# ============================================
# Remove extra spaces and standardize case for text fields
df["invoice_number"] = df["invoice_number"].str.strip().str.upper()
df["product_code"] = df["product_code"].str.strip().str.upper()
df["product_description"] = df["product_description"].str.strip()
df["country"] = df["country"].str.strip()

# Quick checks after formatting cleanup
print("\nEmpty descriptions:", df["product_description"].str.strip().eq("").sum())
print("Unique countries:", df["country"].nunique())

#%%
# ============================================
# 7. Remove exact duplicate rows
# ============================================
before_rows = len(df)

#Inspect duplicates before removing them
df[df.duplicated()]

#%%
df = df.drop_duplicates()

after_rows = len(df)
print(f"\nRemoved {before_rows - after_rows} duplicate rows")

validate_df(df, "After Deduplication")

#%%
# ============================================
# 8. Engineer invoice-related features
# ============================================
# Identify cancellations and adjustments from invoice number prefixes
df["is_cancelled"] = df["invoice_number"].str.startswith("C")
df["is_adjustment"] = df["invoice_number"].str.startswith("A")

# Extract numeric invoice ID for grouping transactions together
df["invoice_id"] = df["invoice_number"].str.replace(r"[^0-9]", "", regex=True)

# Classify transaction type
df["transaction_type"] = np.where(
    df["is_cancelled"], "Cancelled",
    np.where(df["is_adjustment"], "Adjustment", "Purchase")
)

print("\nTransaction type counts:")
print(df["transaction_type"].value_counts())
print("Cancelled rows:", df["is_cancelled"].sum())

#%%
# ============================================
# 9. Engineer product-related features
# ============================================
# Extract numeric base product code
df["base_product_code"] = df["product_code"].str.extract(r"^(\d+)")

# Extract letter suffix for product variants
df["product_variant"] = df["product_code"].str.extract(r"([A-Z]+)$")

# Flag valid product codes: digits followed by optional letters
df["is_valid_product"] = df["product_code"].str.match(r"^\d+[A-Z]*$", na=False)

print("\nInvalid product codes:", (~df["is_valid_product"]).sum())
print(df.loc[~df["is_valid_product"], "product_description"].value_counts().head())

#%%
# ============================================
# 10. Standardize product descriptions
# ============================================
# Create mapping: product_code = most common description
desc_map = (
    df.dropna(subset=['product_description'])
      .groupby('product_code')['product_description']
      .agg(lambda x: x.mode()[0])
)

# Apply mapping to make descriptions consistent
df['product_description'] = df['product_code'].map(desc_map).fillna('UNKNOWN_PRODUCT')

# Clean extra spaces
df['product_description'] = df['product_description'].str.replace(r'\s+', ' ', regex=True).str.strip()

# Check for any missing values
print("\nMissing descriptions:", df['product_description'].isnull().sum())

#%%
# ============================================
# 11. Standardize country names
# ============================================
# Clean country labels for consistency 
df["country"] = df["country"].replace({
    "EIRE": "Ireland",
    "USA": "United States",
    "RSA": "South Africa",
    "Korea": "South Korea"
})

print("\nCountry value counts:")
print(df["country"].value_counts(dropna=False))

#%%
# ============================================
# 12. Calculate revenue
# ============================================
# Revenue is quantity multiplied by unit price
df['revenue'] = (df['quantity'] * df['price']).round(2)

print("\nRevenue summary:")
print(df["revenue"].describe())
print("Negative revenue rows:", (df["revenue"] < 0).sum())

#%%
# ============================================
# 13. Remove duplicates created by standardization
# ============================================
before_rows = len(df)
df = df.drop_duplicates()
after_rows = len(df)

print(f"\nRemoved {before_rows - after_rows} duplicates after final standardization")

#%%
# ============================================
# 14. Final validation
# ============================================
validate_df(df, "Final Cleaned Data")

# Final integrity checks
assert df["invoice_number"].notna().all(), "Missing invoice numbers found"
assert df["invoice_date"].notna().all(), "Missing invoice dates found"
assert df["price"].notna().all(), "Missing prices found"
assert df.duplicated().sum() == 0, "Duplicate rows still exist"
#%%
# ============================================
# 15. Key findings
# ============================================
print("\n--- Key Findings ---")
print("Final row count:", len(df))
print("Rows removed as duplicates:", before_rows - after_rows)
print("Invalid product codes:", (~df["is_valid_product"]).sum())
print("Negative quantity rows:", (df["quantity"] < 0).sum())
print("Negative price rows:", (df["price"] < 0).sum())
print("Cancelled rows:", df["is_cancelled"].sum())
print("Adjustment rows:", df["is_adjustment"].sum())
print("Missing customer IDs:", df["customer_id"].isna().sum())
# %%
# ============================================
# 16. Save to CSV 
# ============================================
export_cols = [
    'invoice_number',
    'product_code',
    'product_description',
    'quantity',
    'invoice_date',
    'price',
    'customer_id',
    'country',
    'is_cancelled',
    'is_adjustment',
    'invoice_id',
    'transaction_type',
    'base_product_code',
    'product_variant',
    'is_valid_product',
    'revenue'
]
df[export_cols].to_csv("retail_cleaned.csv", index=False)

# %%
