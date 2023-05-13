 /*--------------------------------------------------------------------------------*
|                         CREATE TABLE FOR MONEY MANAGER                          |
*--------------------------------------------------------------------------------*/

-- This table is based to the exported xls file from the Money Manager app
CREATE TABLE money_traffic.money_manager
(
    date           timestamp,
    account        varchar(50),
    category       varchar(100),
    subcategory    varchar(100),
    note           varchar(200),
    amount         numeric(15, 2),
    income_expense varchar(50) CHECK (income_expense IN ('Income', 'Expense'))
);

/*----------------------------------------------------------------------------------*
|  CREATE FUNCTION THAT CALCULATES MONTHLY EXPENSES AND MONTHLY AVERAGES PER YEAR   |
*----------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION fn_show_monthly_expenses()
    RETURNS TABLE -- The function needs to return the following fields in report like table
            (
                year            int,
                month           int,
                monthly_amount  numeric(15, 2),
                monthly_average numeric(15, 2)
            )
AS
$$
BEGIN
    RETURN QUERY
        -- Fetch the Total expenses per month for each individual month of the data, in a CTE
        WITH monthly_expenses AS (SELECT date_part('year', date)::int  AS year
                                       , date_part('month', date)::int AS month
                                       , sum(amount)::numeric(15, 2)   AS total_amount
                                  FROM money_traffic.money_manager
                                  WHERE income_expense = 'Expense'
                                  GROUP BY ROLLUP (year, month)
                                  ORDER BY year NULLS LAST, month NULLS LAST)
             -- Select the fields from the CTE
        SELECT me.year
             , me.month
             , me.total_amount
             , CASE -- calculate the monthly_average based on the yearly_amount/12
                   WHEN me.month NOTNULL THEN NULL
                   ELSE (me.total_amount / 12)
               END AS monthly_average
        FROM monthly_expenses me;
END;
$$ LANGUAGE plpgsql;

/*----------------------------------------------------------------------------------*
|       CREATE FUNCTION THAT CALCULATES ADDITIONAL RENT & BILLS AND INFLATION       |
*----------------------------------------------------------------------------------*/

-- This function calculates the inflation and rent and bills,in case the rent and bills are not included in the data.
-- If rent & bills are included in the data set the input parameter = 0
CREATE OR REPLACE FUNCTION fn_show_monthly_expenses_with_inflation(rent_bills numeric(15, 2), inflation_percentage numeric(15, 2))
    RETURNS table -- The function needs to return the following fields in report like table
            (
                year            int,
                month           int,
                monthly_amount  numeric(15, 2),
                monthly_average numeric(15, 2),
                bills           numeric(15, 2),
                inflation       numeric(15, 2)
            )
AS
$$
DECLARE
    -- Initialize the input variables
    rb numeric(15, 2) := rent_bills;
    i  numeric(15, 2) := inflation_percentage;
BEGIN
    RETURN QUERY
        SELECT *                                          -- Fetch all the data from the `fn_show_monthly_expenses`
             , me.monthly_average + rb       AS bills     -- Calculate Rent & Bills
             , (me.monthly_average + rb) * i AS inflation -- Include Inflation
        FROM fn_show_monthly_expenses() me;
END;
$$ LANGUAGE plpgsql;

/*--------------------------------------*
|            USEFUL QUERIES             |
*--------------------------------------*/

-- Fetch all the Expenses from the table
SELECT *
FROM money_manager
WHERE income_expense = 'Expense';

-- Calculate all monthly and yearly expenses in report like format
SELECT date_part('year', date)::int  AS year
     , date_part('month', date)::int AS month
     , sum(amount)::numeric(15, 2)   AS total_amount
FROM money_traffic.money_manager
WHERE income_expense = 'Expense'
GROUP BY ROLLUP (year, month)
ORDER BY year NULLS LAST, month NULLS LAST;

-- Calculate Rent & Bills and Inflation
-- In case Rent & Bills are Included in the data set the parameter rent_bills = 0
-- Ignore WHERE statement to fetch all data
SELECT *
FROM fn_show_monthly_expenses_with_inflation(600.00, 1.10)
WHERE year = 2022;

