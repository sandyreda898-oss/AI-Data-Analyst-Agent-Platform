IF DB_ID('DataCoSupplyChainDB') IS NULL
	BEGIN
	CREATE DATABASE DataCoSupplyChainDB;
END;
GO

USE DataCoSupplyChainDB;
GO

---------- Duplicate ID Columns
-- Customer ID vs Order Customer ID 
SELECT COUNT(*) AS CustomerIDMismatches
FROM dbo.DataCo_cleaned
WHERE
TRY_CONVERT(INT, customer_id) <> TRY_CONVERT(INT, order_customer_id)
OR (TRY_CONVERT(INT, customer_id) IS NULL
AND TRY_CONVERT(INT, order_customer_id) IS NOT NULL)
OR (TRY_CONVERT(INT, customer_id) IS NOT NULL
AND TRY_CONVERT(INT, order_customer_id) IS NULL);
GO

-- Product ID vs Order Item Product ID
SELECT COUNT(*) AS ProductIDMismatches
FROM dbo.DataCo_cleaned
WHERE
TRY_CONVERT(INT, product_card_id) <> TRY_CONVERT(INT, order_item_cardprod_id)
OR (TRY_CONVERT(INT, product_card_id) IS NULL
AND TRY_CONVERT(INT, order_item_cardprod_id) IS NOT NULL)
OR (TRY_CONVERT(INT, product_card_id) IS NOT NULL
AND TRY_CONVERT(INT, order_item_cardprod_id) IS NULL);
GO

-- Category ID vs Product Category ID
SELECT COUNT(*) AS CategoryIDMismatches
FROM dbo.DataCo_cleaned
WHERE
TRY_CONVERT(INT, category_id) <> TRY_CONVERT(INT, product_category_id)
OR (TRY_CONVERT(INT, category_id) IS NULL
AND TRY_CONVERT(INT, product_category_id) IS NOT NULL)
OR (TRY_CONVERT(INT, category_id) IS NOT NULL
AND TRY_CONVERT(INT, product_category_id) IS NULL);
GO

CREATE TABLE dbo.Customers(
CustomerID INT NOT NULL,
FirstName NVARCHAR(100) NULL,
LastName NVARCHAR(100) NULL,
Segment NVARCHAR(50) NULL,
City NVARCHAR(150) NULL,
State NVARCHAR(100) NULL,
Country NVARCHAR(150) NULL,
Street NVARCHAR(300) NULL,
Zipcode NVARCHAR(20) NULL,
Latitude DECIMAL(10,7) NULL,
Longitude DECIMAL(11,7) NULL,
CONSTRAINT PK_Customers
PRIMARY KEY (CustomerID));
GO

CREATE TABLE dbo.Departments(
DepartmentID INT NOT NULL,
DepartmentName NVARCHAR(150) NULL,
CONSTRAINT PK_Departments
PRIMARY KEY (DepartmentID));
GO

CREATE TABLE dbo.Categories(
CategoryID INT NOT NULL,
CategoryName NVARCHAR(200) NULL,
DepartmentID INT NOT NULL,
CONSTRAINT PK_Categories
PRIMARY KEY (CategoryID),

CONSTRAINT FK_Categories_Departments
FOREIGN KEY (DepartmentID) 
REFERENCES dbo.Departments(DepartmentID));
GO

CREATE TABLE dbo.Products(
ProductID INT NOT NULL,
CategoryID INT NOT NULL,
ProductName NVARCHAR(500) NULL,
ProductPrice DECIMAL(18,4) NULL,
ProductStatus BIT NULL,

CONSTRAINT PK_Products
PRIMARY KEY (ProductID),

CONSTRAINT FK_Products_Categories
FOREIGN KEY (CategoryID)
REFERENCES dbo.Categories(CategoryID));
GO

CREATE TABLE dbo.Orders(
OrderID INT NOT NULL,
CustomerID INT NOT NULL,
OrderDate DATETIME2(0) NULL,
PaymentType NVARCHAR(50) NULL,
Market NVARCHAR(100) NULL,
OrderRegion NVARCHAR(150) NULL,
OrderCountry NVARCHAR(150) NULL,
OrderState NVARCHAR(150) NULL,
OrderCity NVARCHAR(150) NULL,
OrderZipcode NVARCHAR(20) NULL,
OrderStatus NVARCHAR(100) NULL,
DeliveryStatus NVARCHAR(100) NULL,
LateDeliveryRisk BIT NULL,
DaysForShippingReal INT NULL,
DaysForShipmentScheduled INT NULL,
ShippingDate DATETIME2(0) NULL,
ShippingMode NVARCHAR(100) NULL,

CONSTRAINT PK_Orders
PRIMARY KEY (OrderID),

CONSTRAINT FK_Orders_Customers
FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID));
GO

CREATE TABLE dbo.OrderItems(
OrderItemID INT NOT NULL,
OrderID INT NOT NULL,
ProductID INT NOT NULL,
Quantity INT NULL,
ProductPrice DECIMAL(18,4) NULL,
DiscountAmount DECIMAL(18,4) NULL,
DiscountRate DECIMAL(12,8) NULL,
Sales DECIMAL(18,4) NULL,
OrderItemTotal DECIMAL(18,4) NULL,
ProfitRatio DECIMAL(12,8) NULL,
ProfitAmount DECIMAL(18,4) NULL,
BenefitPerOrder DECIMAL(18,4) NULL,
SalesPerCustomer DECIMAL(18,4) NULL,

CONSTRAINT PK_OrderItems
PRIMARY KEY (OrderItemID),

CONSTRAINT FK_OrderItems_Orders
FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),

CONSTRAINT FK_OrderItems_Products
FOREIGN KEY (ProductID) REFERENCES dbo.Products(ProductID));
GO

--------
;WITH DepartmentRows AS(SELECT
TRY_CONVERT(INT, department_id) AS DepartmentID,
CAST(department_name AS NVARCHAR(150)) AS DepartmentName,
ROW_NUMBER() OVER(PARTITION BY TRY_CONVERT(INT, department_id)
ORDER BY CAST(department_name AS NVARCHAR(150))) AS rn
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, department_id) IS NOT NULL)

INSERT INTO dbo.Departments(
DepartmentID,
DepartmentName)

SELECT
DepartmentID,
DepartmentName
FROM DepartmentRows
WHERE rn = 1;
GO

----
;WITH CategoryRows AS(SELECT
TRY_CONVERT(INT, category_id) AS CategoryID,
CAST(category_name AS NVARCHAR(200)) AS CategoryName,
TRY_CONVERT(INT, department_id) AS DepartmentID,
ROW_NUMBER() OVER(PARTITION BY TRY_CONVERT(INT, category_id)
ORDER BY TRY_CONVERT(INT, department_id)) AS rn
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, category_id) IS NOT NULL
AND TRY_CONVERT(INT, department_id) IS NOT NULL)

INSERT INTO dbo.Categories(
CategoryID,
CategoryName,
DepartmentID)

SELECT
CategoryID,
CategoryName,
DepartmentID
FROM CategoryRows
WHERE rn = 1;
GO

-----
;WITH ProductRows AS(SELECT
TRY_CONVERT(INT, product_card_id) AS ProductID,
TRY_CONVERT(INT, category_id) AS CategoryID,
CAST(product_name AS NVARCHAR(500)) AS ProductName,
TRY_CONVERT(DECIMAL(18,4), product_price) AS ProductPrice,
TRY_CONVERT(BIT, product_status) AS ProductStatus,
ROW_NUMBER() OVER (PARTITION BY TRY_CONVERT(INT, product_card_id)
ORDER BY TRY_CONVERT(INT, order_item_id)) AS rn
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, product_card_id) IS NOT NULL
AND TRY_CONVERT(INT, category_id) IS NOT NULL)


INSERT INTO dbo.Products
(ProductID,
CategoryID,
ProductName,
ProductPrice,
ProductStatus)

SELECT
ProductID,
CategoryID,
ProductName,
ProductPrice,
ProductStatus
FROM ProductRows
WHERE rn = 1;
GO


SELECT COUNT(*) AS ProductsWithoutCategory
FROM dbo.Products AS p
LEFT JOIN dbo.Categories AS c
ON p.CategoryID = c.CategoryID
WHERE c.CategoryID IS NULL;
GO
------
;WITH CustomerRows AS(SELECT
TRY_CONVERT(INT, customer_id) AS CustomerID,
CAST(customer_fname AS NVARCHAR(100)) AS FirstName,
CAST(customer_lname AS NVARCHAR(100)) AS LastName,
CAST(customer_segment AS NVARCHAR(50)) AS Segment,
CAST(customer_city AS NVARCHAR(150)) AS City,
CAST(customer_state AS NVARCHAR(100)) AS State,
CAST(customer_country AS NVARCHAR(150)) AS Country,
CAST(customer_street AS NVARCHAR(300)) AS Street,
CAST(customer_zipcode AS NVARCHAR(20)) AS Zipcode,
TRY_CONVERT(DECIMAL(10,7), latitude) AS Latitude,
TRY_CONVERT(DECIMAL(11,7), longitude) AS Longitude,
ROW_NUMBER() OVER(PARTITION BY TRY_CONVERT(INT, customer_id)
ORDER BY TRY_CONVERT(INT, order_id)) AS rn
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, customer_id) IS NOT NULL)

INSERT INTO dbo.Customers
(CustomerID,
FirstName,
LastName,
Segment,
City,
State,
Country,
Street,
Zipcode,
Latitude,
Longitude)

SELECT
CustomerID,
FirstName,
LastName,
Segment,
City,
State,
Country,
Street,
Zipcode,
Latitude,
Longitude
FROM CustomerRows
WHERE rn = 1;
GO

----
;WITH OrderRows AS(SELECT
TRY_CONVERT(INT, order_id) AS OrderID,
TRY_CONVERT(INT, order_customer_id) AS CustomerID,
TRY_CONVERT(DATETIME2(0), order_date_dateorders) AS OrderDate,
CAST([type] AS NVARCHAR(50)) AS PaymentType,
CAST(market AS NVARCHAR(100)) AS Market,
CAST(order_region AS NVARCHAR(150)) AS OrderRegion,
CAST(order_country AS NVARCHAR(150))  AS OrderCountry,
CAST(order_state AS NVARCHAR(150)) AS OrderState,
CAST(order_city AS NVARCHAR(150)) AS OrderCity,
CAST(order_zipcode AS NVARCHAR(20)) AS OrderZipcode,
CAST(order_status AS NVARCHAR(100)) AS OrderStatus,
CAST(delivery_status AS NVARCHAR(100)) AS DeliveryStatus,
TRY_CONVERT(BIT, late_delivery_risk)  AS LateDeliveryRisk,
TRY_CONVERT(INT, days_for_shipping_real) AS DaysForShippingReal,
TRY_CONVERT(INT, days_for_shipment_scheduled) AS DaysForShipmentScheduled,
TRY_CONVERT(DATETIME2(0), shipping_date_dateorders) AS ShippingDate,
CAST(shipping_mode AS NVARCHAR(100)) AS ShippingMode,
ROW_NUMBER() OVER(PARTITION BY TRY_CONVERT(INT, order_id)
ORDER BY TRY_CONVERT(INT, order_item_id)) AS rn
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, order_id) IS NOT NULL
AND TRY_CONVERT(INT, order_customer_id) IS NOT NULL)

INSERT INTO dbo.Orders
(OrderID,
CustomerID,
OrderDate,
PaymentType,
Market,
OrderRegion,
OrderCountry,
OrderState,
OrderCity,
OrderZipcode,
OrderStatus,
DeliveryStatus,
LateDeliveryRisk,
DaysForShippingReal,
DaysForShipmentScheduled,
ShippingDate,
ShippingMode)

SELECT
OrderID,
CustomerID,
OrderDate,
PaymentType,
Market,
OrderRegion,
OrderCountry,
OrderState,
OrderCity,
OrderZipcode,
OrderStatus,
DeliveryStatus,
LateDeliveryRisk,
DaysForShippingReal,
DaysForShipmentScheduled,
ShippingDate,
ShippingMode
FROM OrderRows
WHERE rn = 1;
GO

SELECT COUNT(*) AS OrdersWithoutCustomer
FROM dbo.Orders AS o
LEFT JOIN dbo.Customers AS c
ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;
GO

----------
INSERT INTO dbo.OrderItems
(OrderItemID,
OrderID,
ProductID,
Quantity,
ProductPrice,
DiscountAmount,
DiscountRate,
Sales,
OrderItemTotal,
ProfitRatio,
ProfitAmount,
BenefitPerOrder,
SalesPerCustomer)


SELECT
TRY_CONVERT(INT, order_item_id) AS OrderItemID,
TRY_CONVERT(INT, order_id) AS OrderID,
TRY_CONVERT(INT, order_item_cardprod_id) AS ProductID,
TRY_CONVERT(INT, order_item_quantity) AS Quantity,
TRY_CONVERT(DECIMAL(18,4), order_item_product_price) AS ProductPrice,
TRY_CONVERT(DECIMAL(18,4), order_item_discount) AS DiscountAmount,
TRY_CONVERT(DECIMAL(12,8), order_item_discount_rate) AS DiscountRate,
TRY_CONVERT(DECIMAL(18,4), sales) AS Sales,
TRY_CONVERT(DECIMAL(18,4), order_item_total) AS OrderItemTotal,
TRY_CONVERT(DECIMAL(12,8), order_item_profit_ratio) AS ProfitRatio,
TRY_CONVERT(DECIMAL(18,4), order_profit_per_order) AS ProfitAmount,
TRY_CONVERT(DECIMAL(18,4), benefit_per_order) AS BenefitPerOrder,
TRY_CONVERT(DECIMAL(18,4), sales_per_customer) AS SalesPerCustomer
FROM dbo.DataCo_cleaned
WHERE TRY_CONVERT(INT, order_item_id) IS NOT NULL
AND TRY_CONVERT(INT, order_id) IS NOT NULL
AND TRY_CONVERT(INT, order_item_cardprod_id) IS NOT NULL;
GO


-------
IF NOT EXISTS
(SELECT 1
FROM sys.indexes
WHERE name = 'IX_Orders_CustomerID'
AND object_id = OBJECT_ID('dbo.Orders'))
BEGIN
CREATE INDEX IX_Orders_CustomerID
ON dbo.Orders(CustomerID);
END;
GO


IF NOT EXISTS
(SELECT 1
FROM sys.indexes
WHERE name = 'IX_Categories_DepartmentID'
AND object_id = OBJECT_ID('dbo.Categories'))
BEGIN
CREATE INDEX IX_Categories_DepartmentID
ON dbo.Categories(DepartmentID);
END;
GO


IF NOT EXISTS
(SELECT 1
FROM sys.indexes
WHERE name = 'IX_Products_CategoryID'
AND object_id = OBJECT_ID('dbo.Products'))
BEGIN
CREATE INDEX IX_Products_CategoryID
ON dbo.Products(CategoryID);
END;
GO


IF NOT EXISTS
(SELECT 1
FROM sys.indexes
WHERE name = 'IX_OrderItems_OrderID'
AND object_id = OBJECT_ID('dbo.OrderItems'))
BEGIN
CREATE INDEX IX_OrderItems_OrderID
ON dbo.OrderItems(OrderID);
END;
GO


IF NOT EXISTS
(SELECT 1
FROM sys.indexes
WHERE name = 'IX_OrderItems_ProductID'
AND object_id = OBJECT_ID('dbo.OrderItems'))
BEGIN
CREATE INDEX IX_OrderItems_ProductID
ON dbo.OrderItems(ProductID);
END;
GO

----- Row Count
SELECT 'DataCo_cleaned' AS TableName, COUNT(*) AS TotalRows
FROM dbo.DataCo_cleaned

UNION ALL
SELECT 'Customers', COUNT(*)
FROM dbo.Customers

UNION ALL
SELECT 'Departments', COUNT(*)
FROM dbo.Departments

UNION ALL
SELECT 'Categories', COUNT(*)
FROM dbo.Categories

UNION ALL
SELECT 'Products', COUNT(*)
FROM dbo.Products

UNION ALL
SELECT 'Orders', COUNT(*)
FROM dbo.Orders

UNION ALL
SELECT 'OrderItems', COUNT(*)
FROM dbo.OrderItems;
GO

------- Check: Each should return 0
SELECT COUNT(*) AS OrdersWithoutCustomer
FROM dbo.Orders AS o
LEFT JOIN dbo.Customers AS c
ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;
GO


SELECT COUNT(*) AS OrderItemsWithoutOrder
FROM dbo.OrderItems AS oi
LEFT JOIN dbo.Orders AS o
ON oi.OrderID = o.OrderID
WHERE o.OrderID IS NULL;
GO


SELECT COUNT(*) AS OrderItemsWithoutProduct
FROM dbo.OrderItems AS oi
LEFT JOIN dbo.Products AS p
ON oi.ProductID = p.ProductID
WHERE p.ProductID IS NULL;
GO


SELECT COUNT(*) AS ProductsWithoutCategory
FROM dbo.Products AS p
LEFT JOIN dbo.Categories AS c
ON p.CategoryID = c.CategoryID
WHERE c.CategoryID IS NULL;
GO


SELECT COUNT(*) AS CategoriesWithoutDepartment
FROM dbo.Categories AS c
LEFT JOIN dbo.Departments AS d
ON c.DepartmentID = d.DepartmentID
WHERE d.DepartmentID IS NULL;
GO

------- Checks for duplicates
SELECT CustomerID, COUNT(*) AS DuplicateCount
FROM dbo.Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;
GO


SELECT OrderID, COUNT(*) AS DuplicateCount
FROM dbo.Orders
GROUP BY OrderID
HAVING COUNT(*) > 1;
GO


SELECT OrderItemID, COUNT(*) AS DuplicateCount
FROM dbo.OrderItems
GROUP BY OrderItemID
HAVING COUNT(*) > 1;
GO


SELECT ProductID, COUNT(*) AS DuplicateCount
FROM dbo.Products
GROUP BY ProductID
HAVING COUNT(*) > 1;
GO


SELECT CategoryID, COUNT(*) AS DuplicateCount
FROM dbo.Categories
GROUP BY CategoryID
HAVING COUNT(*) > 1;
GO


SELECT DepartmentID, COUNT(*) AS DuplicateCount
FROM dbo.Departments
GROUP BY DepartmentID
HAVING COUNT(*) > 1;
GO


-------- Connecting Table (Test)
SELECT TOP (20)
o.OrderID,
o.OrderDate,

c.CustomerID,
c.FirstName,
c.LastName,

oi.OrderItemID,
oi.Quantity,
oi.Sales,

p.ProductID,
p.ProductName,

cat.CategoryID,
cat.CategoryName,

d.DepartmentID,
d.DepartmentName,

o.OrderStatus,
o.DeliveryStatus,
o.ShippingMode
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c
ON o.CustomerID = c.CustomerID

INNER JOIN dbo.OrderItems AS oi
ON o.OrderID = oi.OrderID

INNER JOIN dbo.Products AS p
ON oi.ProductID = p.ProductID

INNER JOIN dbo.Categories AS cat
ON p.CategoryID = cat.CategoryID

INNER JOIN dbo.Departments AS d
ON cat.DepartmentID = d.DepartmentID
ORDER BY o.OrderID;
GO

-------
SELECT
fk.name AS ForeignKeyName,
OBJECT_NAME(fk.parent_object_id) AS ChildTable,
COL_NAME(
fkc.parent_object_id,
fkc.parent_column_id) AS ChildColumn,
OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
COL_NAME(
fkc.referenced_object_id,
fkc.referenced_column_id)
AS ParentColumn
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
ON fk.object_id = fkc.constraint_object_id
ORDER BY
ChildTable,
ForeignKeyName;
GO