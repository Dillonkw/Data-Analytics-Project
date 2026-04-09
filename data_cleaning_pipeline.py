#%%
#Load pandas and numpy libraries
import pandas as pd
import numpy as np
#%%
#Loading in the data
file = "online_retail_II.xlsx" 

df1 = pd.read_excel(file, sheet_name=0)
df2 = pd.read_excel(file, sheet_name=1)

df = pd.concat([df1, df2], ignore_index=True)

print("Combined shape:", df.shape)
print(df.head())

# %%
### Renaming column names ###
df = df.rename(columns={
    'Invoice' : 'invoice_number',
    'StockCode': 'product_code',
    'Description' : 'product_description',
    'Quantity' : 'quantity',
    'InvoiceDate': 'invoice_date',
    'Price' : 'price',
    'Customer ID': 'customer_id',
    'Country' : 'country'
})
df.columns




#%%
# General data quality checks
df.info()
display(df.describe())
display(df.isnull().sum())
display(df.duplicated().sum())






#%%
### Cleaning for invoice_number column ###
#Convert to string 
df['invoice_number'] = df['invoice_number'].astype(str)

#Remove White Spaces
df['invoice_number'] = df['invoice_number'].str.strip()

#Standardize case
df['invoice_number'] = df['invoice_number'].str.upper()

#%% 
### Feature engineering for invoice_number column ###
#Cancelation flag
df['is_cancelled'] = df['invoice_number'].str.startswith('C')

#Adjustment flag 
df['is_adjustment'] = df['invoice_number'].str.startswith('A')

#Extract numeric invoice id (for grouping)
df['invoice_id'] = df['invoice_number'].str.replace('[^0-9]', '', regex=True)

#Transaction type column
df['transaction_type'] = np.where(
    df['invoice_number'].str.startswith('C'), 'Cancelled',
    np.where(df['invoice_number'].str.startswith('A'), 'Adjustment', 'Purchase')
)

df.head(10)
#%%
### Data validation checks ###
#Validity check
df[~df['invoice_number'].str.match(r'^[CA]?\d{6}$')]
#%%
#Missing or null after cleaning 
df['invoice_number'].isnull().sum()
#%%
#Uniqueness
print(df['invoice_number'].nunique())
#Distribution oif transaction types
print(df['transaction_type'].value_counts())

--------------------------------------------------------------
#%%
### Cleaning for product_code column ###
#Convert to string 
df['product_code'] = df['product_code'].astype(str)

#Remove White Spaces
df['product_code'] = df['product_code'].str.strip()

#Standardize case
df['product_code'] = df['product_code'].str.upper()

#%%
### Feature engineering for product_code column ###
#Extract base product code (product code with out varient)
df['base_stockcode'] = df['product_code'].str.extract(r'(\d+)')

#Extract varient letter
df['product_variant'] = df['product_code'].str.extract(r'([A-Z]+)$')

#Clean product_id
df['product_id'] = df['base_stockcode']

#Product type flag
df['has_variant'] = df['product_variant'].notnull()

#Non product product codes
#identify them
df[~df['product_code'].str.match(r'^\d+')]

#Create two dataframes. One with only product codes and one with non product codes
products_df = df[df['product_code'].str.match(r'^\d+[A-Z]+$')]
non_products_df = df[~df['product_code'].str.match(r'^\d+[A-Z]+$')]

products_df.head(10)

#%%
#Data validation check for products_df
#Format check
products_df['product_code'].str.match(r'^\d+[A-Z]+$').value_counts()
#%%
#See if invalid rows exist
products_df[~products_df['product_code'].str.match(r'^\d+[A-Z]+$')]

#%%
#Check for missing values
products_df['product_code'].isnull().sum()

#%%
#Split integrity check
len(products_df) + len(non_products_df) == len(df)






#%%
df.duplicated().sum()

#%%
df_dup = df[df.duplicated(keep=False)]
df_dup

#%%
df_dup.sort_values(['Invoice', 'StockCode']).head(20)

#%%
df[df.duplicated()].head(20)
