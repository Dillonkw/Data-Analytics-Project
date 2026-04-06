#%%
#Load pandas library
import pandas as pd
#%%
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

#%%
# Checking for null values
print(df.isnull().sum())
#%%

#%%
# Checking Data Types
print(df.info())
#%%

#Feature Engineering

