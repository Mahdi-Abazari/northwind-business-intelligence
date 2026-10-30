USE northwinddb;

-- ============================================================================
-- فاز ۴ (بخش ۶.۲): تحلیل سفارش‌ها و ارزیابی عملکرد کارکنان
-- هدف: استفاده از توابع تجمعی، Subqueryها و Join برای سنجش بهره‌وری نیروی انسانی
-- و واکاوی توزیع جغرافیایی هزینه‌های لجستیک
-- ============================================================================

-- ----------------------------------------------------------------------------
-- بخش الف) سنجش بهره‌وری و سابقه فعالیت کارکنان (Productivity Index)
-- ----------------------------------------------------------------------------
SELECT
    TopEmps.EmployeeID,                     -- شناسه کارمند
    TopEmps.FirstName,                      -- نام
    TopEmps.LastName,                       -- نام خانوادگی
    TopEmps.TotalOrders,                    -- کل سفارشات ثبت‌شده توسط این کارمند

    -- محاسبه سابقه کاری (YearsAtCompany):
    -- از آنجا که این دیتاست مربوط به گذشته است، استفاده از توابع تاریخ روز (مثل CURDATE) منطقی نیست.
    -- لذا آخرین تاریخ ثبت شده در جدول سفارشات (MAX OrderDate) به عنوان تاریخ جاری سیستم (Current Date)
    -- فرض شده و تفاضل آن با تاریخ استخدام (HireDate) بر حسب سال (تقسیم بر ۳۶۵.۲۵ برای احتساب سال کبیسه) محاسبه می‌شود.
    ROUND(DATEDIFF((SELECT MAX(OrderDate) FROM Orders), TopEmps.HireDate) / 365.25, 2) AS YearsAtCompany,

    -- محاسبه شاخص بهره‌وری (Productivity Index):
    -- بهره‌وری = تعداد کل سفارشات / تعداد سال‌های حضور در شرکت
    ROUND(
        TopEmps.TotalOrders /
        (DATEDIFF((SELECT MAX(OrderDate) FROM Orders), TopEmps.HireDate) / 365.25),
    2) AS ProductivityIndex

FROM (
    -- زیرپرس‌وجو (Subquery): استخراج ۳ کارمند برتر بر اساس "حجم فروش"
    -- طبق دستورالعمل پروژه، ابتدا باید ۳ کارمندی که بیشترین تعداد سفارش را داشته‌اند فیلتر شوند
    -- و سپس محاسبات بهره‌وری صرفاً روی این ۳ نفر انجام گیرد.
    SELECT
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.HireDate,
        COUNT(o.OrderID) AS TotalOrders     -- شمارش تعداد سفارشات (تابع تجمعی)
    FROM Employees e
    JOIN Orders o ON e.EmployeeID = o.EmployeeID
    GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.HireDate
    ORDER BY TotalOrders DESC
    LIMIT 3                                 -- اعمال فیلتر برای استخراج ۳ نفر برتر
) AS TopEmps
ORDER BY ProductivityIndex DESC;            -- مرتب‌سازی نهایی بر اساس شاخص بهره‌وری از بیشترین به کمترین


-- ----------------------------------------------------------------------------
-- بخش ب) تحلیل هزینه‌های حمل و توزیع جغرافیایی (قاره آمریکا)
-- ----------------------------------------------------------------------------

-- گام ۰: استخراج و راستی‌آزمایی کشورهای موجود در دیتابیس
-- این کوئری تحلیلی برای مستندسازی در گزارش است تا نشان دهیم انتخاب کشورهای
-- حوزه قاره آمریکا بر اساس دیتای واقعی موجود در سیستم (Data-driven) انجام شده است.
SELECT DISTINCT ShipCountry
FROM Orders
ORDER BY ShipCountry;


-- گام ۱: شناسایی رکوردهای برون‌هنجار (Outliers) یا تک‌سفارش‌های بسیار گران‌قیمت
-- در این بخش ۳ سفارشی که به صورت انفرادی بالاترین بار مالی لجستیکی را داشته‌اند استخراج می‌شوند.
SELECT
    OrderID,
    CustomerID,
    OrderDate,
    Freight,                                 -- هزینه حمل سفارش
    ShipCity,
    ShipCountry,
    ShipRegion
FROM Orders
-- فیلتر کردن بازار هدف: فقط کشورهای قاره آمریکا
WHERE ShipCountry IN ('USA','Canada','Brazil','Mexico','Argentina','Venezuela')
ORDER BY Freight DESC                        -- مرتب‌سازی نزولی بر اساس هزینه حمل
LIMIT 3;


-- گام ۲: تحلیل تجمعی (Aggregate) و شناسایی کانون‌های پرهزینه توزیع
-- برخلاف گام ۱ که تک‌تراکنش‌ها را بررسی کرد، این کوئری با استفاده از GROUP BY،
-- هزینه‌ها را در سطح "شهر" تجمیع می‌کند تا مشخص شود کدام شهرها (به طور کلی)
-- بیشترین بودجه حمل‌ونقل را می‌بلعند.
SELECT
    ShipCity,                                -- شهر مقصد
    ShipCountry,                             -- کشور مقصد
    COUNT(*) AS OrderCount,                  -- تعداد کل سفارشات ارسال شده به این شهر
    ROUND(SUM(Freight), 2) AS TotalFreight,  -- مجموع هزینه‌های حمل به این شهر (معیار اصلی مرتب‌سازی)
    ROUND(AVG(Freight), 2) AS AvgFreight     -- میانگین هزینه حمل برای هر سفارش در این شهر
FROM Orders
-- اعمال فیلتر جغرافیایی (قاره آمریکا)
WHERE ShipCountry IN ('USA','Canada','Brazil','Mexico','Argentina','Venezuela')
GROUP BY ShipCity, ShipCountry               -- گروه‌بندی داده‌ها در سطح شهر و کشور
ORDER BY TotalFreight DESC                   -- مرتب‌سازی بر اساس مجموع هزینه حمل
LIMIT 3;                                     -- شناسایی ۳ شهر برتر