
-- 1. Tạo bảng và phân loại sản phẩm
CREATE TABLE ProductCategories (
    ProductCode VARCHAR(50),
    Category VARCHAR(50),
    DetailCategory VARCHAR(50)
);

INSERT INTO ProductCategories (ProductCode, Category, DetailCategory)
SELECT DISTINCT 
    p.ProductCode,
    CASE 
        WHEN p.OrderID = 'DH0002716' THEN 'Export'
        WHEN p.ProductCode IN ('VDD51', 'TP_CDC_200', 'TP_CDC_700', 'TP_CDC_350', 'TP_CDCB_700', 
                               'TP_CDCO_350', 'TP_CDCO_700', 'TP_FG_350', 'TP_FG_700', 'TP_GG_200', 
                               'TP_GG_350', 'TP_GG_700', 'TP_GG_LIT', 'TP_WG_700', 'TP_RUM_350', 
                               'TP_RUM_700', 'TP_CF_700', 'TP_CL_350', 'TP_CF_350', 'TP_CL_700', 
                               'TP_TRS_700', 'TP_TPS_350', 'TP_SMW_750', 'TP_SMW_700') THEN 'VDD'
        WHEN p.ProductCode IN ('TP_RTD_200', 'TP_RTD_MN_200', 'TP_RTD_NG_200', 'TP_RTD_NG_700', 
                               'TP_RTD_NG72_200', 'TP_RTD_CEM_200', 'TP_RTD_CEM_700', 'TP_RTD_DM_200', 
                               'TP_RTD_DM_700', 'TP_RTD_OF_200', 'TP_RTD_OF_700', 'TP_RTD_OM_200', 
                               'TP_RTD_OM_700', 'TP_RTD_PC_200', 'TP_RTD_PC_700', 'TP_RTD_MM_200') THEN 'RTD/RTP'
        ELSE 'Other'
    END AS Category,
    CASE 
        WHEN p.ProductCode IN ('TP_CDC_200', 'TP_CDC_700', 'TP_CDC_350', 'TP_CDCB_700') THEN 'CDC'
        WHEN p.ProductCode IN ('TP_CDCO_350', 'TP_CDCO_700') THEN 'CDCO'
        WHEN p.ProductCode IN ('TP_FG_350', 'TP_FG_700', 'TP_GG_200', 'TP_GG_350', 'TP_GG_700', 'TP_GG_LIT', 'TP_WG_700') THEN 'GIN'
        ELSE 'Other'
    END AS DetailCategory
FROM Products p;

-- 2. Chuẩn bị dữ liệu doanh số theo tháng
WITH SalesData AS (
    SELECT 
        FORMAT(o.OrderDate, 'yyyy - MMMM') AS YearMonth,  
        YEAR(o.OrderDate) * 100 + MONTH(o.OrderDate) AS YearOrder,
        SUM(o.Revenue) AS Total_Revenue, 
        pc.Category
    FROM Orders o
    JOIN Products p ON o.OrderID = p.OrderID
    JOIN ProductCategories pc ON p.ProductCode = pc.ProductCode
    WHERE o.OrderDate > '2024-03-01'
    GROUP BY FORMAT(o.OrderDate, 'yyyy - MMMM'), 
             YEAR(o.OrderDate), MONTH(o.OrderDate), 
             pc.Category
)
SELECT YearMonth, [VDD], [RTD/RTP], [BTV], [Casks], [Other]
FROM (
    SELECT YearMonth, YearOrder, Total_Revenue, Category 
    FROM SalesData
) src
PIVOT (
    SUM(Total_Revenue) 
    FOR Category IN ([VDD], [RTD/RTP], [BTV], [Casks], [Other])
) pvt
ORDER BY YearOrder;

-- 3. Tổng hợp doanh số theo tuần
WITH LastWeek AS (
    SELECT 
        ID, 
        Customers, 
        SUM(Revenue) AS Total_revenue
    FROM orders
    WHERE orderdate > DATEADD(DAY, -7, (SELECT MAX(Orderdate) FROM orders)) -- Lọc 7 ngày gần nhất
    GROUP BY ID, Customers
)
SELECT 
    l.ID, 
    l.Customers, 
    c.SimpleName, 
    l.Total_revenue, 
    c.City, 
    c.Region, 
    c.Category
FROM LastWeek l
JOIN customers c ON l.ID = c.ID
ORDER BY c.Category ASC, l.Total_revenue DESC;


-- 4. Xếp hạng khách hàng theo doanh số
WITH row_num AS (
    SELECT 
        o.id, 
        c.SimpleName, 
        o.total_sales, 
        c.city, 
        c.region, 
        c.category, 
        ROW_NUMBER() OVER (PARTITION BY c.category ORDER BY o.total_sales DESC) AS rn
    FROM customers c
    JOIN (
        SELECT id, SUM(revenue) AS total_sales  
        FROM orders 
        WHERE orderdate >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) 
		AND orderdate < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0)
        GROUP BY id
    ) o ON c.id = o.id 
    WHERE c.category <> 'Event/Promotion'  
)
SELECT id, SimpleName, total_sales, city, region, category 
FROM row_num
WHERE rn <= 5;

-- 5. So sánh doanh số theo mục tiêu
WITH LastWeek AS (
    SELECT 
        Salers, 
        SUM(Revenue) AS Total_Sale, 
        CASE 
			WHEN Salers = 'Brenker Mikey (NV000006)' THEN 200000000
			WHEN Salers = 'Seamus Gough (NV000024)' THEN 200000000
			WHEN Salers = 'Rosen Micheal (NV000004)' THEN 200000000
			WHEN Salers = 'Vlad Bidash (NV000006)' THEN 200000000
			WHEN Salers LIKE  '%NV000020%' THEN 100000000
			ELSE NULL
		END AS Target
    FROM orders 
    WHERE orderdate BETWEEN '2025-03-17' AND '2025-03-22' 
    GROUP BY Salers
), 
March AS (
    SELECT 
        Salers, 
        SUM(Revenue) AS Total_Sale, 
        CASE 
			WHEN Salers = 'Brenker Mikey (NV000006)' THEN 200000000
			WHEN Salers = 'Seamus Gough (NV000024)' THEN 200000000
			WHEN Salers = 'Rosen Micheal (NV000004)' THEN 200000000
			WHEN Salers = 'Vlad Bidash (NV000006)' THEN 200000000
			WHEN Salers LIKE  '%NV000020%' THEN 100000000
			ELSE NULL
		END AS Target
    FROM orders 
    WHERE orderdate BETWEEN '2025-03-01' AND '2025-03-31' 
    GROUP BY Salers
)
SELECT 
    March.Salers, 
    LastWeek.Total_Sale AS LastWeek,
    March.Total_Sale AS ThisMonth, 
    March.Target,
    ROUND(March.Total_Sale * 100.0 / March.Target, 2) AS Percentage  
FROM March
FULL OUTER JOIN LastWeek ON March.Salers = LastWeek.Salers
WHERE March.Target IS NOT NULL
ORDER BY March.Total_Sale DESC;

