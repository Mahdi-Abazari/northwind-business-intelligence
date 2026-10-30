USE northwinddb;

-- ============================================================================
-- فاز ۴ (بخش ۶.۵): طراحی اجزای کاربردی پایگاه داده و آماده‌سازی برای گزارش‌گیری
-- هدف: توسعه نماهای منطقی (Logical Views) برای کپسوله‌سازی منطق تجاری
-- و استفاده از جداول موقت (Temporary Tables) برای پردازش‌های تحلیلی چندمرحله‌ای
-- ============================================================================

-- ----------------------------------------------------------------------------
-- بخش ۶.۵.۱: ساخت نمای منطقی (View) برای محاسبات فروش خالص
-- نکته مهندسی: استفاده از View باعث می‌شود منطق محاسبه فروش خالص یک‌بار در لایه دیتابیس
-- تعریف شود و ابزارهای هوش تجاری (مثل Power BI در فاز ۵) درگیر محاسبات تکراری نشوند.
-- ----------------------------------------------------------------------------

-- ۱. حذف نمای قبلی در صورت وجود (جهت جلوگیری از خطای اجرای مجدد و حفظ خاصیت Idempotent)
DROP VIEW IF EXISTS SalesOrderDetailsView;

-- ۲. ساخت نمای منطقی (View) یکپارچه
CREATE VIEW SalesOrderDetailsView AS
SELECT
    od.OrderID,                             -- شناسه سفارش
    od.ProductID,                           -- شناسه محصول
    p.ProductName,                          -- نام محصول
    p.CategoryID,                           -- شناسه دسته‌بندی
    c.CategoryName,                         -- نام دسته‌بندی (محور اصلی تحلیل در داشبوردها)
    o.OrderDate,                            -- تاریخ سفارش (برای تحلیل‌های سری زمانی)
    o.CustomerID,                           -- شناسه مشتری
    o.EmployeeID,                           -- شناسه کارمند
    o.ShipCountry,                          -- کشور مقصد (برای تحلیل‌های جغرافیایی)
    od.UnitPrice,                           -- قیمت واحد در زمان ثبت سفارش
    od.Quantity,                            -- تعداد سفارش داده شده
    od.Discount,                            -- درصد تخفیف اعمال شده
    -- پیاده‌سازی فرمول تجاری فروش خالص: (تعداد * قیمت) * (۱ - درصد تخفیف)
    (od.UnitPrice * od.Quantity * (1 - od.Discount)) AS SalesNet
FROM Order_Details od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Products p ON od.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID;

-- ۳. تست سریع و اعتبارسنجی نمای ساخته شده
SELECT CategoryName, ROUND(SUM(SalesNet), 2) AS TotalNetSales
FROM SalesOrderDetailsView
GROUP BY CategoryName
ORDER BY TotalNetSales DESC;


-- ----------------------------------------------------------------------------
-- بخش ۶.۵.۲: تحلیل پیشرفته بازارهای استراتژیک با استفاده از جداول موقت (Temporary Tables)
-- نکته مهندسی: به جای اجرای Subqueryهای سنگین و تو در تو که گلوگاه پردازشی ایجاد می‌کنند،
-- مسئله به ۳ جدول موقت (مقیم در RAM سرور) شکسته شده تا اجرای کوئری بهینه‌تر انجام شود.
-- ----------------------------------------------------------------------------

-- ۱. پاک‌سازی جداول موقت از Sessionهای قبلی برای جلوگیری از خطای Duplicate
DROP TEMPORARY TABLE IF EXISTS TopCountries;
DROP TEMPORARY TABLE IF EXISTS PopularCategoryByCountry;
DROP TEMPORARY TABLE IF EXISTS MaxCategorySalesTemp;

-- ۲. ساخت جدول موقت اول: استخراج بازارهای استراتژیک
-- هدف: شناسایی کشورهایی که مجموع خریدشان از میانگین خرید کل کشورها (Global Average) بیشتر است.
CREATE TEMPORARY TABLE TopCountries AS
SELECT ShipCountry, SUM(SalesNet) AS TotalSales
FROM SalesOrderDetailsView
GROUP BY ShipCountry
HAVING TotalSales > (
    -- ساب‌کوئری برای محاسبه میانگین فروش جهانی
    SELECT AVG(CountryTotal) FROM (
        SELECT SUM(SalesNet) AS CountryTotal
        FROM SalesOrderDetailsView
        GROUP BY ShipCountry
    ) AS PerCountry
);

-- ۳. ساخت جدول موقت دوم: محاسبه فروش هر دسته‌بندی فقط در بازارهای استراتژیک
-- هدف: محدود کردن دامنه تحلیل صرفاً به کشورهای برتر (موجود در جدول موقت اول)
CREATE TEMPORARY TABLE PopularCategoryByCountry AS
SELECT v.ShipCountry, v.CategoryName, SUM(v.SalesNet) AS CategorySales
FROM SalesOrderDetailsView v
JOIN TopCountries tc ON v.ShipCountry = tc.ShipCountry
GROUP BY v.ShipCountry, v.CategoryName;

-- ۴. ساخت جدول موقت سوم: یافتن سقف فروش (Maximum Sales) در هر کشور
-- هدف: این جدول یک تکنیک بهینه در MySQL برای یافتن بیشترین مقدار در هر گروه
-- (به عنوان جایگزین سنتی برای Window Functionها) است.
CREATE TEMPORARY TABLE MaxCategorySalesTemp AS
SELECT ShipCountry, MAX(CategorySales) AS MaxCategorySales
FROM PopularCategoryByCountry
GROUP BY ShipCountry;

-- ۵. خروجی نهایی: شناسایی محبوب‌ترین دسته‌بندی محصولات در هر کشور استراتژیک
-- از طریق JOIN زدن جدول دسته‌بندی‌ها با جدول مقادیر ماکزیمم، نام پرفروش‌ترین دسته استخراج می‌شود.
SELECT
    p.ShipCountry,                                 -- کشورهای برتر (بازارهای استراتژیک)
    p.CategoryName,                                -- محبوب‌ترین دسته‌بندی در آن بازار
    ROUND(p.CategorySales, 2) AS MaxCategorySales  -- میزان فروش آن دسته‌بندی (معیار رتبه‌بندی)
FROM PopularCategoryByCountry p
JOIN MaxCategorySalesTemp m
  ON p.ShipCountry = m.ShipCountry AND p.CategorySales = m.MaxCategorySales
ORDER BY MaxCategorySales DESC;                    -- مرتب‌سازی از بزرگترین بازار به کوچکترین