# !pip install mysql-connector-python sqlalchemy

import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Load dataset
df = pd.read_csv('bank_transactions.csv')
# show data
df

#checking data
df.info()
df.head()

#checking data
df.describe(exclude=[int,float])

# Checking and clearning (begin)
# check duplicate
print("Number duplicate", df.duplicated().sum())
# remove duplicate
df.drop_duplicates(inplace = True)

# Drop null
df = df.dropna().reset_index(drop=True)

#check after
df.isnull().sum()

df.describe(exclude=[int,float])

# Feature Engineering: Extract age
# def convert_date(date_str):
#     # Convert to datetime with a cutoff year
#     return pd.to_datetime(date_str, format='%d/%m/%y', errors='coerce', yearfirst=True)

# format date time for CustomerDOB and TransactionDate
df['CustomerDOB'] = pd.to_datetime(df['CustomerDOB'])
df['TransactionDate'] = pd.to_datetime(df['TransactionDate'])

# show data after change the datetime format
df

# Get the current date
current_date = datetime.now().year
# only get data where CustomerDOB year age from 18 to 100


# Subtract 100 years from 'CustomerDOB' where the year is greater than 2000 (ignore this line)
df['CustomerDOB'] = df.apply(
    lambda row: row['CustomerDOB'] - pd.DateOffset(years=100) if row['CustomerDOB'] >= row['TransactionDate'] else row['CustomerDOB'],
    axis=1
)
# find 100 years ago from transaction time
df['cutoff_date'] = pd.to_datetime(df['TransactionDate'].dt.year - 100, format='%Y')
# only get cx with 100 year ago from transaction time
df = df[df['CustomerDOB'].dt.year >= df['cutoff_date'].dt.year]

# only get customer over 18 years old
df = df[df['CustomerDOB'].dt.year <= (df['TransactionDate'].dt.year - 18)]



# # Calculate age
df['Age'] = df['TransactionDate'].dt.year - df['CustomerDOB'].dt.year

# LOAD DATA
# database info
db_host = "localhost"
db_name = "thesis"
db_user = "root"
db_pass = "root123"

# Create connection string
connection_string = f'mysql+mysqlconnector://{db_user}:{db_pass}@{db_host}/{db_name}'

# Create database connection
engine = create_engine(connection_string)

Session = sessionmaker(bind=engine)
session = Session()

df.to_sql('bank_transactions', engine, if_exists='append', index=False, 
          chunksize=1000)  # Process 1000 rows at a time
print(f"Successfully inserted {len(df)} records into the database")

# 1. Create Customer Dimension
customer_dim = df[['CustomerID', 'CustomerDOB', 'CustGender', 'CustLocation', 'CustAccountBalance','Age']]

# Load Customer Dimension to MySQL
customer_dim.to_sql('dimcustomer', con=engine, if_exists='replace', index=False)

# 2. Create Transaction Dimension
transaction_dim = df[['TransactionID', 'TransactionDate', 'TransactionTime', 'TransactionAmount (INR)', 'CustomerID']]

# Rename column to match dimension model
transaction_dim = transaction_dim.rename(columns={'TransactionAmount (INR)': 'TransactionAmount'})

# Load Transaction Dimension to MySQL
transaction_dim.to_sql('dimtransaction', con=engine, if_exists='replace', index=False)

# 3. Create Time Dimension
# Get unique dates from TransactionDate
unique_dates = pd.DataFrame({'Date': df['TransactionDate'].unique()})
unique_dates['Date'] = pd.to_datetime(unique_dates['Date'])

# Add time attributes
unique_dates['Year'] = unique_dates['Date'].dt.year
unique_dates['Month'] = unique_dates['Date'].dt.month
unique_dates['MonthName'] = unique_dates['Date'].dt.strftime('%B')
unique_dates['Quarter'] = unique_dates['Date'].dt.quarter

# Create DateID in format YYYYMMDD as integer
unique_dates['DateID'] = unique_dates['Date'].dt.strftime('%Y%m%d').astype(int)

# Load Time Dimension to MySQL
unique_dates.to_sql('dimtime', con=engine, if_exists='replace', index=False)

print("Dimensional tables created successfully!")

session.close()