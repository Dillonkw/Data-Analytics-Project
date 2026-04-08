#%%
#Load pandas library
import pandas as pd
#%%
#Loading in the data
file = "online_retail_II.xlsx" 

df1 = pd.read_excel(file, sheet_name=0)
df2 = pd.read_excel(file, sheet_name=1)

df = pd.concat([df1, df2], ignore_index=True)

print("Combined shape:", df.shape)
print(df.head())
#%%
### Data Cleaning ###
# Checking for null values
print(df.isnull().sum())
#%%
# Checking Data Types
print(df.info())


# %%
# Renaming column names
df = df.rename(columns={
    'StockCode': 'Stock_code',
    'InvoiceDate': 'Invoice_date',
    'Customer ID': 'Customer_id'
})
# %%
df.columns
# %%
df.head(100)

# %%
df['Invoice'].isnull().sum()
(df['Invoice'] == '').sum()
df[~df['Invoice'].astype(str).str.match(r'^[A-Z]?\d+$')]
df[df['Invoice'].astype(str).str.startswith('C')]
df.groupby('Invoice').size().sort_values(ascending=False)
df['Invoice'].astype(str).str.len().value_counts()
df[~df['Invoice'].astype(str).str.replace('C', '').str.isdigit()]
# %%

def classify_invoice(x):
    if str(x).startswith('C'):
        return 'Cancelled'
    elif str(x).startswith('A'):
        return 'Adjustment'
    elif len(str(x)) == 6 and str(x).isdigit():
        return 'Standard'
    elif str(x).isdigit():
        return 'Other_Numeric'
    else:
        return 'Unknown'

df['InvoiceType'] = df['Invoice'].apply(classify_invoice)

# %%
df['InvoiceType'].value_counts()
# %%
