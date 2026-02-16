-- ADVANCED ANALYSIS
-- Change over time - by year
SELECT
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Changes by month
SELECT
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);

-- Change by year per month
SELECT
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

SELECT
	YEAR(order_date) AS order_year,
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);


SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');

-- Cumulative Analysis
-- Total sales, running total of sales, moving average price over time
SELECT 
	order_date,
	total_sales,
	SUM(total_sales) OVER(ORDER BY order_date) as total_running_sales,
	AVG(avg_price) OVER(ORDER BY order_date) as moving_avg_price
FROM(
SELECT
	DATETRUNC(YEAR, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
)t;

-- Performance analysis
-- Analyze yearly performance of products by comparing each product's sales to both its average sales performance and the previous year's sales
WITH total_yearly_sales AS(
SELECT 
	YEAR(f.order_date) AS order_year,
	p.product_name,
	SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products	p
	ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)
SELECT 
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
	CASE 
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above average'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below average'
		ELSE 'Average'
	END avg_change,
-- Year-over-year analysis
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS py_diff,
	CASE 
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No change'
	END yearly_change
FROM total_yearly_sales
ORDER BY product_name, order_year;

-- Proportional analysis
-- Which categories contribute the most to overall sales?
WITH category_sales AS(
SELECT 
	p.category,
	SUM(s.sales_amount) AS total_sales
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
	ON s.product_key = p.product_key
GROUP BY P.category
)
SELECT 
	category,
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT)/SUM(total_sales) OVER()) * 100, 2), '%') AS pct_total
FROM category_sales
ORDER BY total_sales DESC;

-- Data Segmantation
/*Segment products into cost ranges and count how many
products fall into each segment*/
WITH product_segmentation AS(
SELECT 
	product_key,
	product_name,
	cost,
	CASE
		WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'Above 1000'
	END cost_range
FROM gold.dim_products)
SELECT 
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segmentation
GROUP BY cost_range
ORDER BY total_products DESC;

/*Group customers into three segments based on their spending behaviour:
	- VIP: Customers with at least 12 months of history and spending more than €5,000.
	- Regular: Customers with at least 12 months of history but spending €5,000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/
WITH spending_segment AS(
SELECT 
	c.customer_key,
	MIN(s.order_date) AS first_order, 
	MAX(s.order_date) AS last_order,
	DATEDIFF(MONTH, MIN(s.order_date),MAX(s.order_date)) AS lifespan,
	SUM(s.sales_amount) AS total_spend
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
	ON c.customer_key = s.customer_key
GROUP BY c.customer_key)

SELECT 
	customer_segment,
	COUNT(customer_key) AS total_customers
FROM
	(SELECT
		customer_key,
		total_spend,
		CASE
			WHEN lifespan >= 12 AND total_spend > 5000 THEN 'VIP'
			WHEN lifespan >= 12 AND total_spend <= 5000 THEN 'Regular'
			WHEN lifespan < 12 THEN 'New'
			ELSE ''
		END customer_segment
	FROM spending_segment) t
GROUP BY customer_segment
ORDER BY total_customers DESC;



/*
==============================================================================
CUSTOMER REPORT
==============================================================================
Purpose:
	- This report consolidates key customer metrics and behaviours
Highlights:
	1. Gathers essential fields such as names, age and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
	  - total orders
	  - total sales
	  - total quantity purchased
	  - total products
	  - lifespan (in months)
	4. Calculates valuable KPIs:
	 - recency (months since last order)
	 - average order value
	 - average monthly spend
==============================================================================
*/
GO
CREATE VIEW gold.report_customers AS
WITH base_query AS(
/* ----------------------------------------------------------------------------
1. Base Query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
SELECT 
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name,' ', c.last_name) AS customer_name,
	DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,
	s.order_number,
	s.product_key,
	s.order_date,
	s.sales_amount,
	s.quantity
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON s.customer_key = c.customer_key
WHERE s.order_date IS NOT NULL),

Customer_aggregation AS(
/* ----------------------------------------------------------------------------
2. Customer Aggregations: Summarizes key metrics at the customer level
------------------------------------------------------------------------------*/
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	MAX(order_date) AS last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age)

SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE
		WHEN age < 20 THEN 'Below 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 and 49 THEN '40-49'
		ELSE '50 and Above'
	END AS age_group,
	CASE
			WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
			WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
			WHEN lifespan < 12 THEN 'New'
			ELSE ''
		END customer_segment,
	last_order_date,
	DATEDIFF(month, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	-- Compute average order value (AVO)
	CASE WHEN total_orders = 0 THEN 0
		ELSE total_sales/total_orders 
	END AS avg_order_value,
	-- Compute average monthly spend
	CASE WHEN lifespan = 0 THEN total_sales
		ELSE total_sales/lifespan
	END AS avg_monthly_spend
FROM Customer_aggregation;

SELECT 
customer_segment,
COUNT(customer_number) AS total_customers,
SUM(total_sales) total_sales
FROM gold.report_customers
GROUP BY customer_segment;

/*
==============================================================================
PRODUCT REPORT
==============================================================================
Purpose:
	- This report consolidates key product metrics
Highlights:
	1. Gathers essential fields such as product name, category, subcategory and cost.
	2. Segments products by revenue to identify High-performers, Mid_range, or Low-performers.
	3. Aggregates product-level metrics:
	  - total orders
	  - total sales
	  - total quantity sold
	  - total customers(unique)
	  - lifespan (in months)
	4. Calculates valuable KPIs:
	 - recency (months since last sale)
	 - average order revenue (AOR)
	 - average monthly revenue
==============================================================================
*/

/* ----------------------------------------------------------------------------
1. Base Query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
GO
CREATE VIEW gold.report_products AS
WITH base_query AS(
SELECT 
	s.order_number,
	s.order_date,
	s.customer_key,
	s.quantity,
	s.sales_amount,
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
	ON s.product_key = p.product_key
WHERE order_date IS NOT NULL
),

Product_Aggregation AS(
/* ----------------------------------------------------------------------------
2. Product Aggregations: Summarizes key metrics at the product level
------------------------------------------------------------------------------*/
SELECT 
	product_key,
	category,
	subcategory,
	product_name,
	cost,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) AS last_sale_date,
	COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity_sold,
	SUM(sales_amount) AS total_sales,
	ROUND(AVG(CAST(sales_amount AS FLOAT)/ NULLIF(quantity, 0)),1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	category,
	subcategory,
	product_name,
	cost)

/* ----------------------------------------------------------------------------
3. Final Query combines all product results into one output
------------------------------------------------------------------------------*/
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	CASE 
		WHEN total_sales > 50000 THEN 'High-performer'
		WHEN total_sales >= 10000 THEN 'Mid-range'
		ELSE 'Low-performer'
	END AS product_segments,
	lifespan,
	total_orders,
	total_sales,
	total_quantity_sold,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales/total_orders
	END AS avg_order_revenue,
	-- Average Monthly Revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales/lifespan
	END AS avg_monthly_revenue

FROM product_aggregation