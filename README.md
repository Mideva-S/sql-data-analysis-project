# Project Overview
This project involves an in-depth analysis of global sales data using Microsoft SQL Server. The goal was to transform raw transactional data into actionable business insights through a structured SQL pipeline. I moved beyond basic querying into advanced analytical techniques to provide a "Single Source of Truth" for business reporting.

# 🏗️ Data Architecture & Pipeline
Rather than performing ad-hoc analysis, I built a modular pipeline within SQL Server:
**Raw Data**: Transactional tables covering customers, products, and sales.
**Advanced Transformation (CTEs)**: Utilized Common Table Expressions to perform complex multi-step aggregations and time-series analysis.
**Semantic Layer (Views)**: Developed SQL Views to store the transformed logic, ensuring the data is "reporting-ready" for any BI tool.

# 🛠️ Technical Deep-Dive
## 1. Exploratory Data Analysis (EDA)
Performed initial data profiling to identify:
  Sales distribution across geographical regions. 
  Top-performing product divisions by revenue.
  A report that shows all the key metrics of the business.

## 2. Advanced Analytics with CTEs
I leveraged CTEs to solve complex business logic, such as:
**Year-over-Year (YoY) Growth**: Created a CTE to aggregate sales by year and category, then used a LAG() window function to compare current performance against the   previous year.
**Performance analysis**: Analyze yearly performance of products by comparing each product's sales to both its average sales performance and the previous year's       sales
  
 ```sql
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
```

## 3. Database Object Management
Created SQL Views to simplify the data model. This approach optimizes performance and ensures that the business logic remains consistent across different reports.

# 📂 Project Structure
scripts
[Exploratory Data Analysis script](./scripts/EDA_Project.sql): Contains the full EDA script and View creation logic.

[Advanced Data Analysis script](./scripts/SQL-Advanced-Analysis.sql): Specific snippets for advanced CTE analysis.

# Key Insights
[Insight 1]: (Bikes contribute the most to overall sales at 96.46%.)

[Insight 2]: (United States has the highest number of customers and items sold.)
