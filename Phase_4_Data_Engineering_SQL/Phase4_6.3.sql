USE northwinddb;

-- ============================================================================
-- فاز ۴ (بخش ۶.۳): ارزیابی سیاست‌های قیمت‌گذاری و الگوهای فروش
-- هدف: استفاده از توابع تجمعی و متغیرهای کاربری جهت تحلیل توصیفی و استنباطی داده‌ها
-- ============================================================================

-- ----------------------------------------------------------------------------
-- بخش ۶.۳.۱: تحلیل میانگین قیمت دسته‌بندی‌ها در مقایسه با میانگین کل
-- ----------------------------------------------------------------------------
-- در این کوئری، میانگین قیمت هر دسته‌بندی با استفاده از ساب‌کوئری (Subquery)
-- با میانگین کل محصولات مقایسه می‌شود تا دسته‌های استراتژیک (پایین‌تر یا بالاتر از نرمال) مشخص شوند.
SELECT
    c.CategoryID,                                                -- شناسه دسته
    c.CategoryName,                                              -- نام دسته
    ROUND(AVG(p.UnitPrice), 2) AS CategoryAveragePrice,          -- میانگین قیمت محصولات در این دسته
    (SELECT ROUND(AVG(UnitPrice), 2) FROM Products) AS OverallAveragePrice, -- میانگین قیمت کل محصولات (متغیر مرجع)
    ROUND(AVG(p.UnitPrice) - (SELECT AVG(UnitPrice) FROM Products), 2) AS DifferenceFromAverage, -- میزان انحراف از میانگین کل
    CASE
        -- طبقه‌بندی وضعیت قیمت‌گذاری با استفاده از دستور شرطی
        WHEN AVG(p.UnitPrice) > (SELECT AVG(UnitPrice) FROM Products) THEN 'Higher than Average'
        ELSE 'Lower/Equal to Average'
    END AS PriceStatus
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY CategoryAveragePrice DESC;


-- ----------------------------------------------------------------------------
-- بخش ۶.۳.۲: محاسبه ضریب همبستگی پیرسون (Pearson Correlation)
-- بین متغیرهای کمّی «حجم خرید» (Quantity) و «میزان تخفیف» (Discount)
-- ----------------------------------------------------------------------------
-- از آنجا که هر دو متغیر عددی هستند، استفاده از ضریب پیرسون برای سنجش رابطه خطی مجاز است.
SELECT
    COUNT(*) AS TotalRecords,
    ROUND(
        -- پیاده‌سازی فرمول ریاضی ضریب پیرسون در سطح پایگاه داده
        (COUNT(*) * SUM(od.Discount * od.Quantity) - SUM(od.Discount) * SUM(od.Quantity)) /
        (
            SQRT(COUNT(*) * SUM(POW(od.Discount, 2)) - POW(SUM(od.Discount), 2)) *
            SQRT(COUNT(*) * SUM(POW(od.Quantity, 2)) - POW(SUM(od.Quantity), 2))
        ), 4
    ) AS Pearson_Correlation
FROM Order_Details od;


-- ----------------------------------------------------------------------------
-- بخش ۶.۳.۳: آمار توصیفی — میانگین تخفیف به تفکیک متغیرهای کیفی (Categorical)
-- ----------------------------------------------------------------------------

-- الف) به تفکیک کارمند (بررسی رفتار منابع انسانی در ارائه تخفیف)
SELECT
    e.EmployeeID,
    CONCAT(e.FirstName, ' ', e.LastName) AS FullName,
    ROUND(AVG(od.Discount), 3) AS AvgDiscount,
    COUNT(*) AS LineCount
FROM Order_Details od
JOIN Orders o    ON od.OrderID   = o.OrderID
JOIN Employees e ON o.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, FullName
ORDER BY AvgDiscount DESC;

-- ب) به تفکیک شرکت حمل‌ونقل (بررسی اثر لجستیک بر سیاست تخفیف‌دهی)
SELECT
    s.CompanyName,
    ROUND(AVG(od.Discount), 3) AS AvgDiscount,
    COUNT(*) AS LineCount
FROM Order_Details od
JOIN Orders o   ON od.OrderID = o.OrderID
JOIN Shippers s ON o.ShipVia  = s.ShipperID
GROUP BY s.CompanyName
ORDER BY AvgDiscount DESC;

-- ج) به تفکیک کشور (بررسی استراتژی نفوذ در بازارهای جغرافیایی مختلف)
SELECT
    o.ShipCountry,
    ROUND(AVG(od.Discount), 3) AS AvgDiscount,
    COUNT(*) AS LineCount
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
GROUP BY o.ShipCountry
ORDER BY AvgDiscount DESC;


-- ============================================================================
-- بخش ۶.۳.۴: تحلیل واریانس (ANOVA) — ضریب اتا (Eta) و آماره F
-- هدف: سنجش معناداری آماری رابطه بین متغیرهای کیفی (کارمند، کشور، شرکت باربری)
-- با متغیر کمّی (میزان تخفیف)
-- ----------------------------------------------------------------------------
-- نکته مهندسی داده: از آنجا که در فایل‌های خام، ۷۳ ردیف از Order_Details فاقد
-- سفارش متناظر در Orders بوده‌اند، کلیه محاسبات بر مبنای مجموعه سازگار (N = 2082)
-- حاصل از INNER JOIN انجام شده است تا خطای آماری ایجاد نشود.
-- ============================================================================

-- گام صفر: محاسبه پارامترهای پایه (Total Sum of Squares و میانگین کل) روی مجموعه سازگار
SELECT COUNT(*), AVG(od.Discount),
       SUM(POW(od.Discount - (SELECT AVG(od2.Discount)
                              FROM Order_Details od2
                              JOIN Orders o2 ON od2.OrderID = o2.OrderID), 2))
INTO @N, @GrandMean, @SSTotal
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID;

-- گام ۱: محاسبه Sum of Squares Between (SSB) برای متغیر "کارمند"
SELECT SUM(t.Cnt * POW(t.GroupMean - @GrandMean, 2)), COUNT(*)
INTO @SSB_Emp, @k_Emp
FROM (
    SELECT o.EmployeeID, COUNT(*) AS Cnt, AVG(od.Discount) AS GroupMean
    FROM Order_Details od
    JOIN Orders o ON od.OrderID = o.OrderID
    GROUP BY o.EmployeeID
) t;

-- گام ۲: محاسبه Sum of Squares Between (SSB) برای متغیر "کشور"
SELECT SUM(t.Cnt * POW(t.GroupMean - @GrandMean, 2)), COUNT(*)
INTO @SSB_Cty, @k_Cty
FROM (
    SELECT o.ShipCountry, COUNT(*) AS Cnt, AVG(od.Discount) AS GroupMean
    FROM Order_Details od
    JOIN Orders o ON od.OrderID = o.OrderID
    GROUP BY o.ShipCountry
) t;

-- گام ۳: محاسبه Sum of Squares Between (SSB) برای متغیر "شرکت حمل‌ونقل"
SELECT SUM(t.Cnt * POW(t.GroupMean - @GrandMean, 2)), COUNT(*)
INTO @SSB_Shp, @k_Shp
FROM (
    SELECT o.ShipVia, COUNT(*) AS Cnt, AVG(od.Discount) AS GroupMean
    FROM Order_Details od
    JOIN Orders o ON od.OrderID = o.OrderID
    GROUP BY o.ShipVia
) t;


-- ----------------------------------------------------------------------------
-- خروجی مجزا: جداول تحلیلی پایه (برای درج در بدنه گزارش)
-- ----------------------------------------------------------------------------

-- جدول مجزا ۱: نتیجه آماری بررسی نقش "کارمند" در تخفیف‌دهی
SELECT 'Employee vs Discount' AS Relationship,
       @k_Emp                                AS k_Groups,
       @k_Emp - 1                            AS df1,
       @N - @k_Emp                           AS df2,
       ROUND(@SSB_Emp, 4)                    AS SS_Between,
       ROUND(@SSTotal - @SSB_Emp, 4)         AS SS_Within,
       ROUND(@SSTotal, 4)                    AS SS_Total,
       ROUND(SQRT(@SSB_Emp / @SSTotal), 4)   AS Eta_Correlation,
       ROUND((@SSB_Emp / (@k_Emp - 1)) /
             ((@SSTotal - @SSB_Emp) / (@N - @k_Emp)), 4) AS F_Statistic,
       IF((@SSB_Emp/(@k_Emp-1)) / ((@SSTotal-@SSB_Emp)/(@N-@k_Emp)) > 2.5,
          'Significant', 'Not Significant')  AS Result;

-- جدول مجزا ۲: نتیجه آماری بررسی نقش "کشور مشتری" در تخفیف‌دهی
SELECT 'Country vs Discount' AS Relationship,
       @k_Cty                                AS k_Groups,
       @k_Cty - 1                            AS df1,
       @N - @k_Cty                           AS df2,
       ROUND(@SSB_Cty, 4)                    AS SS_Between,
       ROUND(@SSTotal - @SSB_Cty, 4)         AS SS_Within,
       ROUND(@SSTotal, 4)                    AS SS_Total,
       ROUND(SQRT(@SSB_Cty / @SSTotal), 4)   AS Eta_Correlation,
       ROUND((@SSB_Cty / (@k_Cty - 1)) /
             ((@SSTotal - @SSB_Cty) / (@N - @k_Cty)), 4) AS F_Statistic,
       IF((@SSB_Cty/(@k_Cty-1)) / ((@SSTotal-@SSB_Cty)/(@N-@k_Cty)) > 1.6,
          'Significant', 'Not Significant')  AS Result;

-- جدول مجزا ۳: نتیجه آماری بررسی نقش "شرکت حمل‌ونقل" در تخفیف‌دهی
SELECT 'Shipper vs Discount' AS Relationship,
       @k_Shp                                AS k_Groups,
       @k_Shp - 1                            AS df1,
       @N - @k_Shp                           AS df2,
       ROUND(@SSB_Shp, 4)                    AS SS_Between,
       ROUND(@SSTotal - @SSB_Shp, 4)         AS SS_Within,
       ROUND(@SSTotal, 4)                    AS SS_Total,
       ROUND(SQRT(@SSB_Shp / @SSTotal), 4)   AS Eta_Correlation,
       ROUND((@SSB_Shp / (@k_Shp - 1)) /
             ((@SSTotal - @SSB_Shp) / (@N - @k_Shp)), 4) AS F_Statistic,
       IF((@SSB_Shp/(@k_Shp-1)) / ((@SSTotal-@SSB_Shp)/(@N-@k_Shp)) > 3.0,
          'Significant', 'Not Significant')  AS Result;


-- ----------------------------------------------------------------------------
-- جدول مدیریتی نهایی: تجمیع یافته‌های استنباطی با استفاده از UNION ALL
-- ----------------------------------------------------------------------------
SELECT 'Employee vs Discount' AS Relationship,
       @k_Emp                                AS k_Groups,
       @k_Emp - 1                            AS df1,
       @N - @k_Emp                           AS df2,
       ROUND(@SSB_Emp, 4)                    AS SS_Between,
       ROUND(@SSTotal - @SSB_Emp, 4)         AS SS_Within,
       ROUND(@SSTotal, 4)                    AS SS_Total,
       ROUND(SQRT(@SSB_Emp / @SSTotal), 4)   AS Eta_Correlation,
       ROUND((@SSB_Emp / (@k_Emp - 1)) /
             ((@SSTotal - @SSB_Emp) / (@N - @k_Emp)), 4) AS F_Statistic,
       IF((@SSB_Emp/(@k_Emp-1)) / ((@SSTotal-@SSB_Emp)/(@N-@k_Emp)) > 2.5,
          'Significant', 'Not Significant')  AS Result
UNION ALL
SELECT 'Country vs Discount',
       @k_Cty,
       @k_Cty - 1,
       @N - @k_Cty,
       ROUND(@SSB_Cty, 4),
       ROUND(@SSTotal - @SSB_Cty, 4),
       ROUND(@SSTotal, 4),
       ROUND(SQRT(@SSB_Cty / @SSTotal), 4),
       ROUND((@SSB_Cty / (@k_Cty - 1)) /
             ((@SSTotal - @SSB_Cty) / (@N - @k_Cty)), 4),
       IF((@SSB_Cty/(@k_Cty-1)) / ((@SSTotal-@SSB_Cty)/(@N-@k_Cty)) > 1.6,
          'Significant', 'Not Significant')
UNION ALL
SELECT 'Shipper vs Discount',
       @k_Shp,
       @k_Shp - 1,
       @N - @k_Shp,
       ROUND(@SSB_Shp, 4),
       ROUND(@SSTotal - @SSB_Shp, 4),
       ROUND(@SSTotal, 4),
       ROUND(SQRT(@SSB_Shp / @SSTotal), 4),
       ROUND((@SSB_Shp / (@k_Shp - 1)) /
             ((@SSTotal - @SSB_Shp) / (@N - @k_Shp)), 4),
       IF((@SSB_Shp/(@k_Shp-1)) / ((@SSTotal-@SSB_Shp)/(@N-@k_Shp)) > 3.0,
          'Significant', 'Not Significant');