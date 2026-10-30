USE northwinddb;

-- ============================================================================
-- فاز ۴ (بخش ۶.۴): بهینه‌سازی عملکرد و مدیریت ایندکس‌ها (Performance Tuning)
-- هدف: بررسی تأثیر ایندکس‌های تک‌ستونه و ترکیبی بر روی Query Execution Plan
-- و شبیه‌سازی یک پایگاه داده حجیم (High Volume) با رویکرد Set-Based
-- ============================================================================


-- ----------------------------------------------------------------------------
-- گام ۱: بررسی رفتار دیتابیس در جستجوهای ترکیبی (قبل و بعد از ایندکس)
-- ----------------------------------------------------------------------------

-- ۰. پیاده‌سازی مکانیزم Idempotent (ضدخطا) برای حذف ایندکسِ احتمالی از اجراهای قبلی
-- در این بخش از Dynamic SQL و جستجو در information_schema استفاده شده است تا
-- اگر ایندکس وجود نداشت، اسکریپت با خطا متوقف نشود (یک رویکرد حرفه‌ای در مهندسی داده).
SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'Orders'
      AND index_name = 'idx_orders_customer_date'
);
SET @sql := IF(@idx_exists > 0,
    'DROP INDEX idx_orders_customer_date ON Orders',
    'SELECT ''ایندکس وجود ندارد'' AS msg');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


-- ۱. پلن اجرایی قبل از ایندکس:
-- انتظار می‌رود ستون type برابر ALL باشد، زیرا دیتابیس هیچ ساختار درختی (B-Tree)
-- برای جستجو ندارد و مجبور به اسکن کامل جدول (Full Table Scan) است.
EXPLAIN SELECT * FROM Orders WHERE CustomerID = 'VINET' AND OrderDate > '1996-01-01';

-- ۲. ساخت ایندکس ترکیبی (Composite Index):
-- استفاده از ترکیب دو ستون برای بهینه‌سازی کوئری‌هایی که در WHERE خود
-- شرط‌های ترکیبی (مشتری + تاریخ) دارند.
CREATE INDEX idx_orders_customer_date ON Orders(CustomerID, OrderDate);

-- ۳. پلن اجرایی بعد از ایندکس:
-- انتظار می‌رود ستون type به ref یا range تغییر یابد (Index Seek)،
-- که نشان‌دهنده دسترسی مستقیم به رکوردهای هدف با کمترین هزینه پردازشی است.
EXPLAIN SELECT * FROM Orders WHERE CustomerID = 'VINET' AND OrderDate > '1996-01-01';


-- ============================================================================
-- گام ۲: تولید داده‌های حجیم (تست در مقیاس بالا یا Stress Testing)
-- در این بخش به جای استفاده از حلقه‌های کند (WHILE)، از منطق Set-Based
-- و ضرب دکارتی (CROSS JOIN) برای تولید سریع داده‌ها استفاده شده است.
-- ============================================================================

-- حذف ایمن و ساخت مجدد ساختار جدول تستی
DROP TABLE IF EXISTS Test_Large_Orders;
CREATE TABLE Test_Large_Orders LIKE Orders;

-- تغییر نوع داده کلید اصلی به BIGINT برای جلوگیری از خطای Overflow در شناسه‌های بزرگ
ALTER TABLE Test_Large_Orders MODIFY OrderID BIGINT;

-- ایجاد یک جدول کمکی موقت (Tally/Sequence Table)
-- این جدول اعداد ۰ تا ۹۹۹ را تولید می‌کند تا به عنوان ضریب تکثیر استفاده شود.
DROP TEMPORARY TABLE IF EXISTS Seq;
CREATE TEMPORARY TABLE Seq (n INT);
INSERT INTO Seq (n)
SELECT a.N + b.N*10 + c.N*100
FROM
  (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
   UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
  CROSS JOIN
  (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
   UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
  CROSS JOIN
  (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
   UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c;

-- تزریق داده‌ها به جدول حجیم:
-- ترکیب (CROSS JOIN) جدول Orders (حدود 830 رکورد) با جدول Seq (1000 رکورد)
-- منجر به تولید بیش از 800,000 رکورد در کسری از ثانیه می‌شود.
INSERT INTO Test_Large_Orders
    (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
     ShippedDate, ShipVia, Freight, ShipCity, ShipRegion, ShipCountry)
SELECT
    o.OrderID + (s.n * 100000),      -- فرمول تولید کلید اصلی یکتا برای رکوردهای تکثیرشده
    o.CustomerID, o.EmployeeID, o.OrderDate, o.RequiredDate,
    o.ShippedDate, o.ShipVia, o.Freight, o.ShipCity, o.ShipRegion, o.ShipCountry
FROM Orders o CROSS JOIN Seq s;

-- راستی‌آزمایی حجم داده‌های تزریق شده
SELECT COUNT(*) AS total_rows FROM Test_Large_Orders;


-- ============================================================================
-- گام ۳: مقایسه کارایی با استفاده از ابزار مدرن EXPLAIN ANALYZE
-- نکته مهندسی: به دلیل منسوخ شدن (Deprecation) دستور SHOW PROFILES در
-- MySQL نسخه 8.0 به بعد، از EXPLAIN ANALYZE استفاده شده است که زمان واقعی
-- اجرای کوئری (actual time) را در کنار هزینه پردازشی (cost) ارائه می‌دهد.
-- ============================================================================

-- ۱. تست جستجو بدون ایندکس:
-- دیتابیس مجبور است بیش از 800,000 رکورد را برای یافتن VINET اسکن کند (actual time بسیار بالاست).
EXPLAIN ANALYZE
SELECT COUNT(*) FROM Test_Large_Orders WHERE CustomerID = 'VINET';

-- ۲. ساخت ایندکس تک‌ستونه برای بهینه‌سازی
-- از آنجا که جدول در خطوط قبلی Drop و مجدداً ایجاد شده، این خط کاملاً ایمن است.
CREATE INDEX idx_test_customer ON Test_Large_Orders(CustomerID);

-- ۳. تست جستجو پس از اعمال ایندکس:
-- دیتابیس با کمک درخت ایندکس مستقیماً به رکوردهای هدف می‌رود (actual time به چند میلی‌ثانیه کاهش می‌یابد).
EXPLAIN ANALYZE
SELECT COUNT(*) FROM Test_Large_Orders WHERE CustomerID = 'VINET';