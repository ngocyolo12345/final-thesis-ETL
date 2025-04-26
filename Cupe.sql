-- 1. Age Group Analysis with Transaction Patterns
WITH customer_age AS (
    SELECT 
        CustomerID,
        Age,
        CASE 
            WHEN Age < 25 THEN 'Young Adult'
            WHEN Age < 40 THEN 'Adult'
            WHEN Age < 60 THEN 'Middle Age'
            ELSE 'Senior'
        END as age_group
    FROM DimCustomer
)
SELECT 
    ca.age_group,
    COUNT(DISTINCT t.TransactionID) as total_transactions,
    AVG(t.TransactionAmount) as avg_transaction_amount,
    SUM(t.TransactionAmount) as total_amount,
    COUNT(DISTINCT ca.CustomerID) as unique_customers
FROM customer_age ca
JOIN DimTransaction t ON ca.CustomerID = t.CustomerID
JOIN DimTime dt ON t.TransactionDate = dt.Date
GROUP BY ca.age_group
ORDER BY total_amount DESC;

-- 2. Gender-based Transaction Analysis by Quarter
SELECT 
    dt.Year,
    dt.Quarter,
    cd.CustGender,
    COUNT(td.TransactionID) as transaction_count,
    AVG(td.TransactionAmount) as avg_transaction_value,
    SUM(td.TransactionAmount) as total_amount,
    MAX(td.TransactionAmount) as highest_transaction,
    MIN(td.TransactionAmount) as lowest_transaction
FROM DimCustomer cd
JOIN DimTransaction td ON cd.CustomerID = td.CustomerID
JOIN DimTime dt ON td.TransactionDate = dt.Date
GROUP BY dt.Year, dt.Quarter, cd.CustGender
ORDER BY dt.Year, dt.Quarter;

-- 3. Location-based Transaction Pattern Analysis
SELECT 
    cd.CustLocation,
    EXTRACT(HOUR FROM td.TransactionTime) as hour_of_day,
    COUNT(*) as transaction_count,
    AVG(td.TransactionAmount) as avg_amount,
    SUM(td.TransactionAmount) as total_amount
FROM DimCustomer cd
JOIN DimTransaction td ON cd.CustomerID = td.CustomerID
GROUP BY cd.CustLocation, EXTRACT(HOUR FROM td.TransactionTime)
ORDER BY cd.CustLocation, hour_of_day;

-- 4. Account Balance vs Transaction Analysis
WITH customer_transaction_stats AS (
    SELECT 
        cd.CustomerID,
        cd.CustAccountBalance,
        COUNT(td.TransactionID) as transaction_count,
        AVG(td.TransactionAmount) as avg_transaction_amount,
        SUM(td.TransactionAmount) as total_spent
    FROM DimCustomer cd
    LEFT JOIN DimTransaction td ON cd.CustomerID = td.CustomerID
    GROUP BY cd.CustomerID, cd.CustAccountBalance
)
SELECT 
    CASE 
        WHEN CustAccountBalance < 1000 THEN 'Low Balance'
        WHEN CustAccountBalance < 5000 THEN 'Medium Balance'
        WHEN CustAccountBalance < 10000 THEN 'High Balance'
        ELSE 'Very High Balance'
    END as balance_category,
    COUNT(*) as customer_count,
    AVG(transaction_count) as avg_transactions_per_customer,
    AVG(avg_transaction_amount) as avg_transaction_value,
    SUM(total_spent) as total_amount_spent
FROM customer_transaction_stats
GROUP BY CASE 
    WHEN CustAccountBalance < 1000 THEN 'Low Balance'
    WHEN CustAccountBalance < 5000 THEN 'Medium Balance'
    WHEN CustAccountBalance < 10000 THEN 'High Balance'
    ELSE 'Very High Balance'
END;

-- 5. Monthly Transaction top 3 Trends by Customer Demographics
WITH RankedTransactions AS (
    SELECT 
        dt.Month,
        cd.CustLocation,
        COUNT(td.TransactionID) AS transaction_count,
        SUM(td.TransactionAmount) AS total_amount,
        AVG(td.TransactionAmount) AS avg_transaction_value,
        ROW_NUMBER() OVER (PARTITION BY dt.Month ORDER BY SUM(td.TransactionAmount) DESC) AS ranking
    FROM 
        DimTransaction td
    JOIN 
        DimCustomer cd ON td.CustomerID = cd.CustomerID
    JOIN 
        DimTime dt ON td.TransactionDate = dt.Date
    GROUP BY 
        cd.CustLocation, dt.Month
)
SELECT 
    Month,
    CustLocation,
    transaction_count,
    total_amount,
    avg_transaction_value
FROM 
    RankedTransactions
WHERE 
    ranking <= 3
ORDER BY 
    Month, ranking;

-- 6. Customer Age and Transaction Time Analysis
SELECT 
    CASE 
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 60000 AND 110000 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 120000 AND 160000 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 170000 AND 210000 THEN 'Evening'
        ELSE 'Night'
    END as time_of_day,
    CASE 
        WHEN Age < 25 THEN 'Young Adult'
        WHEN Age < 40 THEN 'Adult'
        WHEN Age < 60 THEN 'Middle Age'
        ELSE 'Senior'
    END as age_group,
    COUNT(*) as transaction_count,
    AVG(td.TransactionAmount) as avg_amount
FROM DimTransaction td
JOIN DimCustomer cd ON td.CustomerID = cd.CustomerID
GROUP BY 
    CASE 
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 60000 AND 110000 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 120000 AND 160000 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM td.TransactionTime) BETWEEN 170000 AND 210000 THEN 'Evening'
        ELSE 'Night'
    END,
    CASE 
        WHEN Age < 25 THEN 'Young Adult'
        WHEN Age < 40 THEN 'Adult'
        WHEN Age < 60 THEN 'Middle Age'
        ELSE 'Senior'
    END;

-- 7. Customer Transaction Frequency Analysis
WITH transaction_frequency AS (
    SELECT 
        cd.CustomerID,
        cd.CustGender,
        cd.CustLocation,
        COUNT(td.TransactionID) as transaction_count,
        SUM(td.TransactionAmount) as total_amount,
        MAX(td.TransactionDate) as last_transaction_date,
        MIN(td.TransactionDate) as first_transaction_date
    FROM DimCustomer cd
    LEFT JOIN DimTransaction td ON cd.CustomerID = td.CustomerID
    GROUP BY cd.CustomerID, cd.CustGender, cd.CustLocation
)
SELECT 
    CustGender,
    CustLocation,
    CASE 
        WHEN transaction_count = 0 THEN 'No Transactions'
        WHEN transaction_count <= 2 THEN 'Low Frequency'
        WHEN transaction_count <= 5 THEN 'Medium Frequency'
        ELSE 'High Frequency'
    END as frequency_category,
    COUNT(*) as customer_count,
    AVG(total_amount) as avg_total_amount
FROM transaction_frequency
GROUP BY CustGender, CustLocation,
    CASE 
        WHEN transaction_count = 0 THEN 'No Transactions'
        WHEN transaction_count <= 2 THEN 'Low Frequency'
        WHEN transaction_count <= 5 THEN 'Medium Frequency'
        ELSE 'High Frequency'
    END;

-- 8. Quarterly Transaction Growth Analysis
WITH quarterly_transactions AS (
    SELECT 
        dt.Year,
        dt.Quarter,
        COUNT(td.TransactionID) as transaction_count,
        SUM(td.TransactionAmount) as total_amount
    FROM DimTransaction td
    JOIN DimTime dt ON td.TransactionDate = dt.Date
    GROUP BY dt.Year, dt.Quarter
)
SELECT 
    Year,
    Quarter,
    transaction_count,
    total_amount,
    LAG(total_amount) OVER (ORDER BY Year, Quarter) as prev_quarter_amount,
    ((total_amount - LAG(total_amount) OVER (ORDER BY Year, Quarter)) / 
     LAG(total_amount) OVER (ORDER BY Year, Quarter)) * 100 as quarter_over_quarter_growth
FROM quarterly_transactions
ORDER BY Year, Quarter;

select * from dimtime;	