/*==============================================================================
 * Stored Procedure: usp_ComplexQueryParserTest
 * Purpose: Comprehensive SQL parser testing procedure
 * Author: Database Team
 * Created: 2025-02-13
 * 
 * Description:
 * This stored procedure demonstrates various SQL syntax patterns including:
 * - Multiple join types (INNER, LEFT, RIGHT, FULL OUTER, CROSS)
 * - CTEs with windowing functions
 * - Nested subqueries
 * - Temp table operations
 * - Old-style comma joins
 * - Various UPDATE and DELETE patterns
 * 
 * NOTE: All changes are rolled back - no permanent data modifications occur
 *==============================================================================*/

create PROCEDURE dbo.usp_ComplexQueryParserTest
AS
BEGIN
    -- Start transaction to ensure rollback works
    /* Transaction block begins here 
       This ensures all operations can be rolled back
       -- Inline comment: Transaction isolation level is default (READ COMMITTED)
    */
    BEGIN TRANSACTION;
    
    BEGIN TRY
        /*----------------------------------------------------------------------
         * SECTION 1: Initial CTE with Product Sales Data
         * This section creates a CTE with windowing functions to rank products
         * /* Nested comment: Uses ROW_NUMBER, RANK, and DENSE_RANK */
         * Performance note: Ensure indexes exist on ProductID and CategoryID
         *----------------------------------------------------------------------*/
        
        -- CTE to get initial product and sales data with windowing functions
        WITH ProductSalesCTE AS (
            SELECT 
                p.ProductID,                    -- Primary key from Product table
                p.Name AS ProductName,          -- Product display name
                p.ProductNumber,                -- SKU or product code
                pc.Name AS CategoryName,        -- Category for grouping
                /* Aggregated metrics
                   -- Total quantity sold across all orders
                   -- Total revenue from all sales
                */
                SUM(sod.OrderQty) AS TotalQuantity,
                SUM(sod.LineTotal) AS TotalSales,
                
                /*==============================================================
                 * Windowing Functions Section
                 * ROW_NUMBER: Unique sequential number within partition
                 * -- Used for identifying top products per category
                 * RANK: Allows gaps in ranking for ties
                 * DENSE_RANK: No gaps in ranking
                 *==============================================================*/
                ROW_NUMBER() OVER (PARTITION BY pc.Name ORDER BY SUM(sod.LineTotal) DESC) AS CategoryRank,
                RANK() OVER (ORDER BY SUM(sod.OrderQty) DESC) AS QuantityRank,  -- Ranks by quantity sold
                DENSE_RANK() OVER (ORDER BY SUM(sod.LineTotal) DESC) AS SalesRank  -- Ranks by revenue
            FROM AdventureWorks2017.Production.Product p  -- Main product table (with database name)
            /* Join to subcategory table
               -- This provides the link to category hierarchy
               /* Nested: ProductSubcategory acts as bridge table */
            */
            INNER JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
            LEFT JOIN ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID  -- Category may be null
            INNER JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID  -- Sales transactions
            GROUP BY p.ProductID, p.Name, p.ProductNumber, pc.Name
            -- Filter to only include products with significant sales volume
            HAVING SUM(sod.OrderQty) > 100
        )
        
        /*======================================================================
         * Insert CTE results into temporary table for further processing
         * Temp table: #ProductSalesTemp
         * -- This allows us to reuse the CTE results multiple times
         * /* Performance: Temp tables are stored in tempdb */
         *======================================================================*/
        SELECT 
            ProductID,
            ProductName,
            ProductNumber,
            CategoryName,
            TotalQuantity,
            TotalSales,
            CategoryRank,      -- Ranking within category
            QuantityRank,      -- Overall quantity ranking
            SalesRank          -- Overall sales ranking
        INTO #ProductSalesTemp  -- Creating temp table with # prefix
        FROM ProductSalesCTE;

        /*----------------------------------------------------------------------
         * SECTION 2: Complex Query with Old-Style Joins
         * This demonstrates comma-separated table syntax (SQL-89 style)
         * -- Modern code should use explicit JOIN syntax, but parsers need
         * -- to handle legacy code
         * /* Old style: FROM table1, table2 WHERE table1.id = table2.id */
         *----------------------------------------------------------------------*/
        
        -- Query the temp table with older-style joins and windowing functions
        WITH DetailedSalesCTE AS (
            SELECT 
                Category = pst.CategoryName,              -- Category identifier
                pst.ProductName,                          -- Product name
                [Product Number] = pst.ProductNumber,     -- SKU with spaces in alias
                AvgSalesPerProduct = AVG(pst.TotalSales), -- Average sales amount
                MaxQuantity = MAX(pst.TotalQuantity),     -- Peak quantity sold
                pst.TotalQuantity,
                Revenue = pst.TotalSales,                 -- Total revenue
                c.CustomerID,                             -- Customer identifier
                p.FirstName + ' ' + p.LastName AS [Customer Name],  -- Full name with space
                st.Name AS TerritoryName,
                
                /*==============================================================
                 * LAG and LEAD Functions
                 * These window functions access previous/next rows
                 * -- LAG: Gets value from previous row (default 0 if none)
                 * -- LEAD: Gets value from next row
                 * /* Useful for trend analysis and comparisons */
                 *==============================================================*/
                LAG(pst.TotalSales, 1, 0) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales) AS PreviousSales,
                LEAD(pst.TotalSales, 1, 0) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales) AS NextSales,
                
                -- FIRST_VALUE and LAST_VALUE for identifying extremes
                FIRST_VALUE(pst.ProductName) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales DESC) AS TopProduct,
                LAST_VALUE(pst.ProductName) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales DESC 
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS BottomProduct
            
            /*==================================================================
             * OLD STYLE JOIN SYNTAX (SQL-89)
             * Tables listed in FROM clause separated by commas
             * Join conditions specified in WHERE clause
             * -- This is legacy syntax but still valid
             * /* Modern equivalent would use INNER JOIN ... ON ... */
             *==================================================================*/
            FROM #ProductSalesTemp pst,                              -- Temp table created earlier
                 AdventureWorks2017.Sales.SalesOrderDetail sod,      -- Order line items (full path)
                 Sales.SalesOrderHeader soh,                         -- Order headers (schema only)
                 Sales.Customer c,                                   -- Customer information
                 Person.Person p,                                    -- Person details
                 AdventureWorks2017.Sales.SalesTerritory st,         -- Sales territory (full path)
                 (SELECT TOP 1 ProductID FROM Production.Product) crossProd  -- Derived table for cross join
            WHERE 
                -- Join conditions (these would be ON clauses in modern syntax)
                pst.ProductID = sod.ProductID                        -- Link temp table to order details
                AND sod.SalesOrderID = soh.SalesOrderID              -- Link details to header
                AND soh.CustomerID = c.CustomerID                    -- Link order to customer
                AND c.PersonID = p.BusinessEntityID                  -- Link customer to person
                AND soh.TerritoryID = st.TerritoryID                 -- Link order to territory
                
                /*==============================================================
                 * Filter Conditions
                 * Mix of conditions on different tables
                 * -- Some with schema qualification, some without
                 * /* Demonstrates parser handling of mixed qualification */
                 *==============================================================*/
                AND pst.TotalSales > 10000                           -- Revenue threshold (no schema)
                AND soh.OrderDate >= '2013-01-01'                    -- Date filter (no schema)
                AND Sales.SalesOrderDetail.OrderQty > 1              -- Quantity filter (with schema)
                AND st.TerritoryID IS NOT NULL                       -- Exclude null territories
            
            -- Grouping clause for aggregation
            GROUP BY 
                pst.CategoryName,
                pst.ProductName,
                pst.ProductNumber,
                pst.TotalQuantity,
                pst.TotalSales,
                c.CustomerID,
                p.FirstName,
                p.LastName,
                st.Name
            -- Post-aggregation filter
            HAVING AVG(pst.TotalSales) > 5000  /* Only high-value products */
        )
        
        /*----------------------------------------------------------------------
         * Insert CTE results into second temp table
         * This table will be used for UPDATE and DELETE operations
         * -- Demonstrates DML operations on temp tables
         * /* Temp tables are session-specific and auto-drop on disconnect */
         *----------------------------------------------------------------------*/
        SELECT 
            Category,
            ProductName,
            [Product Number],          -- Field with spaces
            AvgSalesPerProduct,
            MaxQuantity,
            TotalQuantity,
            Revenue,
            CustomerID,
            [Customer Name],           -- Field with spaces
            TerritoryName,
            PreviousSales,            -- From LAG function
            NextSales,                -- From LEAD function
            TopProduct,               -- From FIRST_VALUE
            BottomProduct,            -- From LAST_VALUE
            [Discount Applied] = CAST(0 AS BIT),      -- Initialize discount flag
            [Adjusted Revenue] = Revenue              -- Will be modified by UPDATEs
        INTO #FinalSalesTemp  -- Second temp table
        FROM DetailedSalesCTE;

        /*======================================================================
         * SECTION 3: SELECT with Derived Table and Nested Subqueries
         * This section demonstrates:
         * 1. Subquery in FROM clause (derived table)
         * 2. Nested subqueries in SELECT list
         * 3. Subquery in WHERE clause
         * -- Multiple levels of nesting test parser recursion
         * /* Windowing functions applied to derived table results */
         *======================================================================*/
        
        -- SELECT with subquery before FROM and nested subqueries
        SELECT 
            ProductData.ProductID,
            ProductData.ProductName,
            ProductData.Color,
            ProductData.[List Price],
            ProductData.[Category Name],
            ProductData.[Total Orders],
            ProductData.[Avg Revenue Per Order],
            
            /*==================================================================
             * Advanced Windowing Functions
             * NTILE: Divides rows into specified number of groups
             * -- Creates quartiles (4 groups) based on price
             * PERCENT_RANK: Relative rank as percentage (0 to 1)
             * CUME_DIST: Cumulative distribution
             * /* These are useful for statistical analysis */
             *==================================================================*/
            NTILE(4) OVER (ORDER BY ProductData.[List Price]) AS PriceQuartile,
            PERCENT_RANK() OVER (ORDER BY ProductData.[Total Orders]) AS OrderPercentile,
            CUME_DIST() OVER (ORDER BY ProductData.[Avg Revenue Per Order]) AS RevenueCumeDist,
            
            -- Aggregate window functions with PARTITION BY
            SUM(ProductData.[List Price]) OVER (PARTITION BY ProductData.[Category Name]) AS CategoryTotalPrice,
            
            /*==================================================================
             * Moving Average Calculation
             * Uses ROWS frame specification
             * -- 2 PRECEDING and 2 FOLLOWING creates 5-row window
             * /* Centered moving average for smoothing */
             *==================================================================*/
            AVG(ProductData.[Avg Revenue Per Order]) OVER (PARTITION BY ProductData.[Category Name] 
                ORDER BY ProductData.[List Price] 
                ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS MovingAvgRevenue
        
        /*======================================================================
         * DERIVED TABLE (Subquery in FROM clause)
         * This entire SELECT is treated as a table
         * -- Must be aliased (AS ProductData)
         * /* Contains nested subqueries in SELECT list */
         *======================================================================*/
        FROM (
            SELECT 
                p.ProductID,
                ProductName = p.Name,  -- Alias format: Name = Value
                p.Color,
                [List Price] = p.ListPrice,  -- Field with spaces
                
                /*==============================================================
                 * NESTED SUBQUERY - Level 1
                 * Retrieves category name through subcategory
                 * -- Contains another subquery (Level 2) in WHERE clause
                 * /* Double nesting tests parser recursion depth */
                 *==============================================================*/
                [Category Name] = (
                    SELECT pc.Name
                    FROM Production.ProductCategory pc
                    WHERE pc.ProductCategoryID = (
                        /*======================================================
                         * NESTED SUBQUERY - Level 2
                         * Gets category ID from subcategory table
                         * -- Innermost subquery in this chain
                         * /* Correlated to outer query via ProductSubcategoryID */
                         *======================================================*/
                        SELECT psc.ProductCategoryID
                        FROM Production.ProductSubcategory psc
                        WHERE psc.ProductSubcategoryID = p.ProductSubcategoryID
                    )
                ),
                
                /*==============================================================
                 * NESTED SUBQUERY with Aggregate
                 * Counts orders where quantity exceeds product average
                 * -- Correlated subquery (references outer p.ProductID)
                 * /* Contains another subquery for AVG calculation */
                 *==============================================================*/
                [Total Orders] = (
                    SELECT COUNT(DISTINCT sod.SalesOrderID)
                    FROM Sales.SalesOrderDetail sod
                    WHERE sod.ProductID = p.ProductID
                        AND sod.OrderQty > (
                            -- Nested subquery to get average quantity for this product
                            SELECT AVG(OrderQty)
                            FROM AdventureWorks2017.Sales.SalesOrderDetail  -- Full path
                            WHERE ProductID = p.ProductID
                        )
                ),
                
                -- Simple scalar subquery for average revenue
                [Avg Revenue Per Order] = (
                    SELECT AVG(LineTotal)
                    FROM AdventureWorks2017.Sales.SalesOrderDetail innerSod
                    WHERE innerSod.ProductID = p.ProductID
                )
            FROM Production.Product p  -- Main product table
            
            /*==================================================================
             * WHERE clause with IN subquery
             * Limits to top 50 products by revenue
             * -- Subquery contains another nested subquery
             * /* Tests parser handling of subquery in WHERE */
             *==================================================================*/
            WHERE p.ProductID IN (
                SELECT TOP 50 ProductID
                FROM Sales.SalesOrderDetail
                WHERE OrderQty > (
                    /*==========================================================
                     * Nested subquery in WHERE of IN subquery
                     * Calculates 150% of average order quantity
                     * -- Non-correlated subquery
                     * /* Independent calculation */
                     *==========================================================*/
                    SELECT AVG(OrderQty) * 1.5
                    FROM Sales.SalesOrderDetail
                )
                GROUP BY ProductID
                ORDER BY SUM(LineTotal) DESC
            )
        ) AS ProductData  -- Alias required for derived table
        ORDER BY ProductData.[List Price] DESC;

        /*----------------------------------------------------------------------
         * SECTION 4: DML Operations (UPDATE, DELETE)
         * Various UPDATE patterns to test parser
         * -- Pattern 1: UPDATE with table alias
         * -- Pattern 2: UPDATE without alias  
         * -- Pattern 3: UPDATE with JOIN
         * /* All operations will be rolled back */
         *----------------------------------------------------------------------*/
        
        /*======================================================================
         * First UPDATE: Using table alias and subquery
         * Updates records where revenue exceeds both threshold and average
         * -- Table alias (fst) used in UPDATE and SET clauses
         * /* Subquery in WHERE clause for dynamic comparison */
         *======================================================================*/
        UPDATE fst
        SET 
            [Discount Applied] = 1,                    -- Mark as discounted
            [Adjusted Revenue] = fst.Revenue * 0.9     -- Apply 10% discount
        FROM #FinalSalesTemp fst
        WHERE fst.Revenue > 50000
            AND fst.Revenue > (
                -- Subquery to get average revenue across all records
                SELECT AVG(Revenue) 
                FROM #FinalSalesTemp
            );

        /*======================================================================
         * DELETE Operation
         * Removes low revenue records from temp table
         * -- Simple WHERE clause without joins
         * /* This reduces dataset for subsequent operations */
         *======================================================================*/
        DELETE FROM #FinalSalesTemp
        WHERE Revenue < 15000;  -- Remove products below revenue threshold

        /*======================================================================
         * Second UPDATE: Without table alias
         * Direct table reference in UPDATE statement
         * -- No FROM clause needed for single table
         * /* Updates based on territory and discount status */
         *======================================================================*/
        UPDATE #FinalSalesTemp
        SET [Adjusted Revenue] = Revenue * 0.95  -- 5% discount
        WHERE TerritoryName = 'Northwest'        -- Specific territory
            AND [Discount Applied] = 0;          -- Not already discounted

        /*======================================================================
         * Third UPDATE: Using JOIN
         * Demonstrates UPDATE...FROM...JOIN pattern
         * -- Joins temp table with Product table
         * /* Updates based on list price from joined table */
         *======================================================================*/
        UPDATE fst
        SET 
            fst.[Adjusted Revenue] = fst.Revenue * 0.85,  -- 15% discount
            fst.[Discount Applied] = 1                    -- Mark as discounted
        FROM #FinalSalesTemp fst
        INNER JOIN Production.Product p ON fst.ProductName = p.Name
        WHERE p.ListPrice > 1000              -- High-value products only
            AND fst.[Discount Applied] = 0;   -- Not already discounted

        /*----------------------------------------------------------------------
         * SECTION 5: Final Results Query
         * Displays final state of temp table with additional analytics
         * -- Multiple windowing functions for ranking and aggregation
         * /* Running totals and percentage calculations */
         *----------------------------------------------------------------------*/
        
        -- Final SELECT to view results with additional windowing functions
        SELECT 
            *,  -- All existing columns
            
            /*==================================================================
             * ROW_NUMBER for unique sequential numbering
             * -- Orders by adjusted revenue descending
             * /* No ties possible with ROW_NUMBER */
             *==================================================================*/
            ROW_NUMBER() OVER (ORDER BY [Adjusted Revenue] DESC) AS RevenueRowNum,
            
            -- NTILE divides into 10 equal groups (deciles)
            NTILE(10) OVER (ORDER BY [Adjusted Revenue]) AS RevenueDecile,
            
            /*==================================================================
             * Percentage of Total Calculation
             * Divides individual revenue by sum of all revenue
             * -- SUM() OVER() without PARTITION = grand total
             * /* Useful for identifying contribution to total */
             *==================================================================*/
            PercentOfTotal = [Adjusted Revenue] / SUM([Adjusted Revenue]) OVER () * 100,
            
            /*==================================================================
             * Running Total Calculation
             * Cumulative sum from highest to lowest revenue
             * -- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             * /* Frame includes all rows from start to current */
             *==================================================================*/
            RunningTotal = SUM([Adjusted Revenue]) OVER (ORDER BY [Adjusted Revenue] DESC 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        FROM #FinalSalesTemp
        ORDER BY [Adjusted Revenue] DESC;  -- Highest revenue first

        /*----------------------------------------------------------------------
         * Cleanup: Drop temporary tables
         * Temp tables are automatically dropped at session end
         * -- Explicit drop is good practice for long-running sessions
         * /* Frees tempdb space immediately */
         *----------------------------------------------------------------------*/
        DROP TABLE #ProductSalesTemp;   -- First temp table
        DROP TABLE #FinalSalesTemp;     -- Second temp table

        /*======================================================================
         * ROLLBACK TRANSACTION
         * This ensures NO permanent changes to the database
         * -- All INSERTs, UPDATEs, and DELETEs are reversed
         * /* Critical for testing without side effects */
         *======================================================================*/
        ROLLBACK TRANSACTION;
        
        -- Success message
        PRINT 'Procedure completed successfully. All changes rolled back.';
        
    END TRY
    
    /*==========================================================================
     * ERROR HANDLING BLOCK
     * Catches any errors during execution
     * -- Ensures transaction is rolled back even on error
     * /* Re-raises error for caller to handle */
     *==========================================================================*/
    BEGIN CATCH
        -- If error occurs, rollback
        /* Check if transaction is still active
           -- @@TRANCOUNT returns number of active transactions
           /* If > 0, we need to rollback */
        */
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        /*======================================================================
         * Error Information Retrieval
         * Gets details about the error that occurred
         * -- ERROR_MESSAGE: Text description of error
         * -- ERROR_SEVERITY: Severity level (1-25)
         * -- ERROR_STATE: Error state number
         * /* Used for logging and debugging */
         *======================================================================*/
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Re-throw the error to caller
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

/*==============================================================================
 * END OF STORED PROCEDURE
 * 
 * To execute: EXEC dbo.usp_ComplexQueryParserTest;
 * To drop: DROP PROCEDURE dbo.usp_ComplexQueryParserTest;
 * 
 * -- This procedure makes no permanent changes due to ROLLBACK
 * /* Safe for testing in any environment */
 *==============================================================================*/