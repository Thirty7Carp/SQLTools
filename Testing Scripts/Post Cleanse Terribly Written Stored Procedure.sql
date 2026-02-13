

CREATE PROCEDURE dbo.usp_ComplexQueryParserTest
AS
BEGIN
    
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        
        
        
        WITH ProductSalesCTE AS (
            SELECT 
                p.ProductID,                    
                p.Name AS ProductName,          
                p.ProductNumber,                
                pc.Name AS CategoryName,        
                
                SUM(sod.OrderQty) AS TotalQuantity,
                SUM(sod.LineTotal) AS TotalSales,
                
                
                ROW_NUMBER() OVER (PARTITION BY pc.Name ORDER BY SUM(sod.LineTotal) DESC) AS CategoryRank,
                RANK() OVER (ORDER BY SUM(sod.OrderQty) DESC) AS QuantityRank,  
                DENSE_RANK() OVER (ORDER BY SUM(sod.LineTotal) DESC) AS SalesRank  
            FROM AdventureWorks2017.Production.Product p  
            
            INNER JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
            LEFT JOIN ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID  
            INNER JOIN Sales.SalesOrderDetail sod ON p.ProductID = sod.ProductID  
            GROUP BY p.ProductID, p.Name, p.ProductNumber, pc.Name
            
            HAVING SUM(sod.OrderQty) > 100
        )
        
        
        SELECT 
            ProductID,
            ProductName,
            ProductNumber,
            CategoryName,
            TotalQuantity,
            TotalSales,
            CategoryRank,      
            QuantityRank,      
            SalesRank          
        INTO #ProductSalesTemp  
        FROM ProductSalesCTE;

        
        
        
        WITH DetailedSalesCTE AS (
            SELECT 
                Category = pst.CategoryName,              
                pst.ProductName,                          
                [Product Number] = pst.ProductNumber,     
                AvgSalesPerProduct = AVG(pst.TotalSales), 
                MaxQuantity = MAX(pst.TotalQuantity),     
                pst.TotalQuantity,
                Revenue = pst.TotalSales,                 
                c.CustomerID,                             
                p.FirstName + ' ' + p.LastName AS [Customer Name],  
                st.Name AS TerritoryName,
                
                
                LAG(pst.TotalSales, 1, 0) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales) AS PreviousSales,
                LEAD(pst.TotalSales, 1, 0) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales) AS NextSales,
                
                
                FIRST_VALUE(pst.ProductName) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales DESC) AS TopProduct,
                LAST_VALUE(pst.ProductName) OVER (PARTITION BY pst.CategoryName ORDER BY pst.TotalSales DESC 
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS BottomProduct
            
            
            FROM #ProductSalesTemp pst,                              
                 AdventureWorks2017.Sales.SalesOrderDetail sod,      
                 Sales.SalesOrderHeader soh,                         
                 Sales.Customer c,                                   
                 Person.Person p,                                    
                 AdventureWorks2017.Sales.SalesTerritory st,         
                 (SELECT TOP 1 ProductID FROM Production.Product) crossProd  
            WHERE 
                
                pst.ProductID = sod.ProductID                        
                AND sod.SalesOrderID = soh.SalesOrderID              
                AND soh.CustomerID = c.CustomerID                    
                AND c.PersonID = p.BusinessEntityID                  
                AND soh.TerritoryID = st.TerritoryID                 
                
                
                AND pst.TotalSales > 10000                           
                AND soh.OrderDate >= '2013-01-01'                    
                AND Sales.SalesOrderDetail.OrderQty > 1              
                AND st.TerritoryID IS NOT NULL                       
            
            
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
            
            HAVING AVG(pst.TotalSales) > 5000  
        )
        
        
        SELECT 
            Category,
            ProductName,
            [Product Number],          
            AvgSalesPerProduct,
            MaxQuantity,
            TotalQuantity,
            Revenue,
            CustomerID,
            [Customer Name],           
            TerritoryName,
            PreviousSales,            
            NextSales,                
            TopProduct,               
            BottomProduct,            
            [Discount Applied] = CAST(0 AS BIT),      
            [Adjusted Revenue] = Revenue              
        INTO #FinalSalesTemp  
        FROM DetailedSalesCTE;

        
        
        
        SELECT 
            ProductData.ProductID,
            ProductData.ProductName,
            ProductData.Color,
            ProductData.[List Price],
            ProductData.[Category Name],
            ProductData.[Total Orders],
            ProductData.[Avg Revenue Per Order],
            
            
            NTILE(4) OVER (ORDER BY ProductData.[List Price]) AS PriceQuartile,
            PERCENT_RANK() OVER (ORDER BY ProductData.[Total Orders]) AS OrderPercentile,
            CUME_DIST() OVER (ORDER BY ProductData.[Avg Revenue Per Order]) AS RevenueCumeDist,
            
            
            SUM(ProductData.[List Price]) OVER (PARTITION BY ProductData.[Category Name]) AS CategoryTotalPrice,
            
            
            AVG(ProductData.[Avg Revenue Per Order]) OVER (PARTITION BY ProductData.[Category Name] 
                ORDER BY ProductData.[List Price] 
                ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS MovingAvgRevenue
        
        
        FROM (
            SELECT 
                p.ProductID,
                ProductName = p.Name,  
                p.Color,
                [List Price] = p.ListPrice,  
                
                
                [Category Name] = (
                    SELECT pc.Name
                    FROM Production.ProductCategory pc
                    WHERE pc.ProductCategoryID = (
                        
                        SELECT psc.ProductCategoryID
                        FROM Production.ProductSubcategory psc
                        WHERE psc.ProductSubcategoryID = p.ProductSubcategoryID
                    )
                ),
                
                
                [Total Orders] = (
                    SELECT COUNT(DISTINCT sod.SalesOrderID)
                    FROM Sales.SalesOrderDetail sod
                    WHERE sod.ProductID = p.ProductID
                        AND sod.OrderQty > (
                            
                            SELECT AVG(OrderQty)
                            FROM AdventureWorks2017.Sales.SalesOrderDetail  
                            WHERE ProductID = p.ProductID
                        )
                ),
                
                
                [Avg Revenue Per Order] = (
                    SELECT AVG(LineTotal)
                    FROM AdventureWorks2017.Sales.SalesOrderDetail innerSod
                    WHERE innerSod.ProductID = p.ProductID
                )
            FROM Production.Product p  
            
            
            WHERE p.ProductID IN (
                SELECT TOP 50 ProductID
                FROM Sales.SalesOrderDetail


                WHERE OrderQty > (
                    
                    SELECT AVG(OrderQty) * 1.5
                    FROM Sales.SalesOrderDetail
                )
                GROUP BY ProductID
                ORDER BY SUM(LineTotal) DESC
            )
        ) AS ProductData  
        ORDER BY ProductData.[List Price] DESC;

        
        
        
        UPDATE fst
        SET 
            [Discount Applied] = 1,                    
            [Adjusted Revenue] = fst.Revenue * 0.9     
        FROM #FinalSalesTemp fst
        WHERE fst.Revenue > 50000
            AND fst.Revenue > (
                
                SELECT AVG(Revenue) 
                FROM #FinalSalesTemp
            );

        
        DELETE FROM #FinalSalesTemp
        WHERE Revenue < 15000;  

        
        UPDATE #FinalSalesTemp
        SET [Adjusted Revenue] = Revenue * 0.95  
        WHERE TerritoryName = 'Northwest'        
            AND [Discount Applied] = 0;          

        
        UPDATE fst
        SET 
            fst.[Adjusted Revenue] = fst.Revenue * 0.85,  
            fst.[Discount Applied] = 1                    
        FROM #FinalSalesTemp fst
        INNER JOIN Production.Product p ON fst.ProductName = p.Name
        WHERE p.ListPrice > 1000              
            AND fst.[Discount Applied] = 0;   

        
        
        
        SELECT 
            *,  
            
            
            ROW_NUMBER() OVER (ORDER BY [Adjusted Revenue] DESC) AS RevenueRowNum,
            
            
            NTILE(10) OVER (ORDER BY [Adjusted Revenue]) AS RevenueDecile,
            
            
            PercentOfTotal = [Adjusted Revenue] / SUM([Adjusted Revenue]) OVER () * 100,
            
            
            RunningTotal = SUM([Adjusted Revenue]) OVER (ORDER BY [Adjusted Revenue] DESC 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        FROM #FinalSalesTemp
        ORDER BY [Adjusted Revenue] DESC;  

        
        DROP TABLE #ProductSalesTemp;   
        DROP TABLE #FinalSalesTemp;     

        
        ROLLBACK TRANSACTION;
        
        
        PRINT 'Procedure completed successfully. All changes rolled back.';
        
    END TRY
    
    
    BEGIN CATCH
        
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

Completion time: 2026-02-13T08:34:09.3098710+08:00
