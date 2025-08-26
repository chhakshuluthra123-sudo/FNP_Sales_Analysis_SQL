use fnp_sales_analysis;
select * from customers;
ALTER TABLE orders MODIFY Order_Date DATE;
ALTER TABLE orders MODIFY Order_Time TIME;
ALTER TABLE orders MODIFY Delivery_Date DATE;
ALTER TABLE orders MODIFY Delivery_Time TIME;
SET SQL_SAFE_UPDATES = 0;

UPDATE orders
SET Order_Date = STR_TO_DATE(Order_Date, '%d-%m-%Y');

SET SQL_SAFE_UPDATES = 1;
UPDATE orders
SET Delivery_Date = STR_TO_DATE(Delivery_Date, '%d-%m-%Y');

~~Total Revenue

SELECT ROUND(SUM(o.Quantity * p.`Price (INR)`), 2) AS total_revenue_inr
FROM Orders o
JOIN Products p ON p.Product_ID = o.Product_ID;

~~Average Order and Delivery Time

SELECT 
    AVG(TIMESTAMPDIFF(
        SECOND,
        CONCAT(o.Order_Date, ' ', o.Order_Time),
        CONCAT(o.Delivery_Date, ' ', o.Delivery_Time)
    )) / 86400 AS avg_delivery_days
FROM Orders o;

~~Monthly Sales Performance

SELECT 
    month(o.Order_Date) AS month,
    SUM(o.Quantity * 'p.Price (INR)') AS revenue
FROM Orders o
JOIN Products p 
    ON p.Product_ID = o.Product_ID
WHERE YEAR(o.Order_Date) = 2023
GROUP BY month
ORDER BY month;


~~Top Products by Revenue

SELECT p.Product_Name, 
       SUM(o.Quantity * p.`Price (INR)`) AS revenue
FROM Orders o
JOIN Products p ON p.Product_ID = o.Product_ID
GROUP BY p.Product_Name
ORDER BY revenue DESC
LIMIT 10;


~~Customer Spending

SELECT c.Customer_ID, c.Name,
       SUM(o.Quantity * p.`Price (INR)`) AS total_spend,
       AVG(o.Quantity * p.`Price (INR)`) AS avg_order_value
FROM Orders o
JOIN Products p ON p.Product_ID = o.Product_ID
JOIN Customers c ON c.Customer_ID = o.Customer_ID
GROUP BY c.Customer_ID, c.Name
ORDER BY total_spend DESC;

~~Top 5 Products – Sales Trend (monthly)

SELECT 
    MONTH(o.Order_Date) AS month,
    p.Product_Name,
    SUM(o.Quantity * p.`Price (INR)`) AS revenue
FROM Orders o
JOIN Products p 
    ON p.Product_ID = o.Product_ID
JOIN (
    SELECT o2.Product_ID
    FROM Orders o2
    JOIN Products p2 ON p2.Product_ID = o2.Product_ID
    GROUP BY o2.Product_ID
    ORDER BY SUM(o2.Quantity * p2.`Price (INR)`) DESC
    LIMIT 5
) top5
    ON p.Product_ID = top5.Product_ID
GROUP BY month, p.Product_Name
ORDER BY month, revenue DESC;

~~Top 10 Cities by Orders

SELECT o.Location AS city, COUNT(DISTINCT o.Order_ID) AS total_orders
FROM Orders o
GROUP BY o.Location
ORDER BY total_orders DESC
LIMIT 10;


~~Order Quantity vs Delivery Time

SELECT 
    o.Quantity,
    AVG(
        TIMESTAMPDIFF(
            SECOND, CONCAT(o.Order_Date, ' ', o.Order_Time),
            CONCAT(o.Delivery_Date, ' ', o.Delivery_Time))
    ) / 86400 AS avg_delivery_days
FROM Orders o
GROUP BY o.Quantity
ORDER BY o.Quantity;


~~Revenue by Occasion

SELECT o.Occasion, SUM(o.Quantity * p.`Price (INR)`) AS revenue
FROM Orders o
JOIN Products p ON p.Product_ID = o.Product_ID
GROUP BY o.Occasion
ORDER BY revenue DESC;


~~Product Popularity by Occasion

SELECT o.Occasion, p.Product_Name, COUNT(DISTINCT o.Order_ID) AS order_count
FROM Orders o
JOIN Products p ON p.Product_ID = o.Product_ID
GROUP BY o.Occasion, p.Product_Name
ORDER BY o.Occasion, order_count DESC;

Customer Retention 
~Repeat vs One-Time Buyers

SELECT 
    CASE WHEN order_count > 1 THEN 'Repeat Buyer' ELSE 'One-Time Buyer' END AS customer_type,
    COUNT(*) AS num_customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Customers), 2) AS percentage
FROM (
    SELECT customer_id, COUNT(order_id) AS order_count
    FROM Orders
    GROUP BY customer_id
) t
GROUP BY customer_type;


~~Churned Customers (No orders in last 90 days)

SELECT c.customer_id, c.name, MAX(o.order_date) AS last_order_date
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
HAVING DATEDIFF(CURDATE(), MAX(o.order_date)) > 90;

~~Customer Lifetime Value (CLV) Segmentation
SELECT 
    c.customer_id, 
    c.name,
    SUM(o.Quantity * p.`Price (INR)`) AS lifetime_value,
    CASE 
        WHEN SUM(o.Quantity * p.`Price (INR)`) >= 20000 THEN 'High Value'
        WHEN SUM(o.Quantity * p.`Price (INR)`) BETWEEN 10000 AND 19999 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
join products p on o.product_id=p.product_id
GROUP BY c.customer_id, c.name
ORDER BY lifetime_value DESC;

~~Cohort Analysis (Retention)
WITH FirstOrder AS (
    SELECT customer_id, MIN(order_date) AS first_purchase
    FROM Orders
    GROUP BY customer_id
),
Cohorts AS (
    SELECT o.customer_id,
            DATE_FORMAT(f.first_purchase, '%Y-%m') AS cohort_month,
           TIMESTAMPDIFF(MONTH, f.first_purchase, o.order_date) AS months_since_signup
    FROM Orders o
    JOIN FirstOrder f ON o.customer_id = f.customer_id
)
SELECT cohort_month, months_since_signup, COUNT(DISTINCT customer_id) AS active_customers
FROM Cohorts
GROUP BY cohort_month, months_since_signup
ORDER BY cohort_month, months_since_signup;


~~Delivery Performance Impact

Delivery Days vs Repeat Purchase Rate

WITH DeliveryStats AS (
    SELECT customer_id,
           AVG(DATEDIFF(delivery_date, order_date)) AS avg_delivery_time,
           COUNT(order_id) AS total_orders
    FROM Orders
    GROUP BY customer_id
)
SELECT CASE 
            WHEN avg_delivery_time <= 2 THEN 'Fast Delivery'
            WHEN avg_delivery_time BETWEEN 3 AND 5 THEN 'Medium Delivery'
            ELSE 'Slow Delivery'
       END AS delivery_speed,
       AVG(total_orders) AS avg_orders_per_customer
FROM DeliveryStats
GROUP BY delivery_speed;

~~Geographic Opportunity (Tier-1 vs Tier-2)
SELECT location,
       COUNT(order_id) AS total_orders,
       SUM(o.Quantity * p.`Price (INR)`) AS revenue,
       AVG(o.Quantity * p.`Price (INR)`) AS avg_order_value
FROM Orders o
join Products p 
on o.product_id=p.product_id
GROUP BY location
ORDER BY revenue DESC;


~~Gender vs Occasion Preferences

SELECT c.gender, o.occasion, COUNT(o.order_id) AS total_orders
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id
GROUP BY c.gender, o.occasion
ORDER BY c.gender, total_orders DESC;


~~High-Value Customer Targeting
WITH RankedSpend AS (
    SELECT 
        customer_id,
        SUM(o.Quantity * p.`Price (INR)`) AS total_spend,
        PERCENT_RANK() OVER (ORDER BY SUM(o.Quantity * p.`Price (INR)`)) AS pr
    FROM Orders o
    join Products p 
on o.product_id=p.product_id
    GROUP BY customer_id
)
SELECT c.customer_id, c.name, rs.total_spend, COUNT(o.order_id) AS total_orders,
       MAX(o.occasion) AS fav_occasion
FROM RankedSpend rs
JOIN Customers c ON rs.customer_id = c.customer_id
JOIN Orders o ON rs.customer_id = o.customer_id
WHERE rs.pr >= 0.95
GROUP BY c.customer_id, c.name, rs.total_spend
ORDER BY rs.total_spend DESC;

~~ End of Project
