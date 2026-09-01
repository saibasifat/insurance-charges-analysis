-- SECTION 1: BASIC EXPLORATION

SELECT * FROM insurance;

SELECT COUNT(*) AS total_records FROM insurance;

SELECT ROUND(AVG(Age),2) AS avg_age,
       ROUND(AVG(Charges),2) AS avg_charge,
       ROUND(AVG(BMI),2) AS bmi_avg
FROM insurance;

SELECT Gender, COUNT(*) AS customer_count
FROM insurance
GROUP BY Gender;

SELECT Gender, Smoker, Region, ROUND(AVG(Charges), 2) AS avg_charge
FROM insurance
GROUP BY Gender, Smoker, Region;


-- SECTION 2: BMI CATEGORY BREAKDOWN

SELECT
  CASE
    WHEN BMI < 18.5 THEN 'Underweight'
    WHEN BMI BETWEEN 18.5 AND 24.9 THEN 'Normal'
    WHEN BMI BETWEEN 25 AND 30 THEN 'Overweight'
    ELSE 'Obese'
  END AS bmi_category,
  ROUND(AVG(Charges), 2) AS avg_charge,
  COUNT(*) AS n
FROM insurance
GROUP BY bmi_category;


-- SECTION 3: CHILDREN GROUP BREAKDOWN

SELECT Children, ROUND(AVG(Charges), 2) AS avg_charges, COUNT(*) AS count_customers
FROM insurance
GROUP BY Children
ORDER BY Children;


-- SECTION 4: MEDIAN CHARGES (MySQL has no
-- PERCENTILE_CONT, so median is computed via
-- window functions)

-- Median charges, overall

WITH ranked AS (
  SELECT Charges,
         ROW_NUMBER() OVER (ORDER BY Charges) AS rn,
         COUNT(*) OVER () AS cnt
  FROM insurance
)
SELECT ROUND(AVG(Charges), 2) AS median_charge
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- Median charges, by Smoker status
WITH ranked AS (
  SELECT Charges, Smoker,
         ROW_NUMBER() OVER (PARTITION BY Smoker ORDER BY Charges) AS rn,
         COUNT(*) OVER (PARTITION BY Smoker) AS cnt
  FROM insurance
)
SELECT Smoker,
       ROUND(AVG(Charges), 2) AS median_charge,
       MAX(cnt) AS n
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
GROUP BY Smoker;

-- Median charges, by BMI category

WITH bmi AS (
  SELECT Charges,
    CASE
      WHEN BMI < 18.5 THEN 'Underweight'
      WHEN BMI BETWEEN 18.5 AND 24.9 THEN 'Normal'
      WHEN BMI BETWEEN 25 AND 30 THEN 'Overweight'
      ELSE 'Obese'
    END AS bmi_category
  FROM insurance
),
ranked AS (
  SELECT Charges, bmi_category,
         ROW_NUMBER() OVER (PARTITION BY bmi_category ORDER BY Charges) AS rn,
         COUNT(*) OVER (PARTITION BY bmi_category) AS cnt
  FROM bmi
)
SELECT bmi_category,
       ROUND(AVG(Charges), 2) AS median_charge,
       MAX(cnt) AS n
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
GROUP BY bmi_category;


-- SECTION 5: SMOKER x BMI INTERACTION
-- (the headline finding of this project)

SELECT Smoker,
  CASE
    WHEN BMI < 18.5 THEN 'Underweight'
    WHEN BMI BETWEEN 18.5 AND 24.9 THEN 'Normal'
    WHEN BMI BETWEEN 25 AND 30 THEN 'Overweight'
    ELSE 'Obese'
  END AS bmi_category,
  ROUND(AVG(Charges), 2) AS avg_charge,
  COUNT(*) AS n
FROM insurance
GROUP BY Smoker, bmi_category
ORDER BY avg_charge DESC;


-- SECTION 6: OUTLIER CHECK
-- (IQR method, computed SEPARATELY within each
-- smoker group -- pooling smokers and non-smokers
-- together would flag the entire smoker population
-- as "outliers" simply because they're a distinct
-- cost distribution, not because of bad data)

WITH ranked AS (
  SELECT Charges, Smoker,
         PERCENT_RANK() OVER (PARTITION BY Smoker ORDER BY Charges) AS pct_rank
  FROM insurance
),
quartiles AS (
  SELECT Smoker,
         MAX(CASE WHEN pct_rank <= 0.25 THEN Charges END) AS q1_approx,
         MAX(CASE WHEN pct_rank <= 0.75 THEN Charges END) AS q3_approx
  FROM ranked
  GROUP BY Smoker
)
SELECT i.Smoker, i.Charges, q.q1_approx, q.q3_approx,
       (q.q3_approx - q.q1_approx) AS iqr,
       q.q3_approx + 1.5 * (q.q3_approx - q.q1_approx) AS upper_fence
FROM insurance i
JOIN quartiles q ON i.Smoker = q.Smoker
WHERE i.Charges > q.q3_approx + 1.5 * (q.q3_approx - q.q1_approx);


-- SECTION 7: HIGH-RISK SEGMENTS
-- (Gender + Smoker + Region)

SELECT Gender, Smoker, Region, ROUND(AVG(Charges), 2) AS avg_charge, COUNT(*) AS n
FROM insurance
WHERE Smoker = 'yes'
GROUP BY Gender, Smoker, Region
ORDER BY avg_charge DESC;