-- ============================================================================
-- فاز ۴ (بخش ۶.۱): طراحی و ایجاد ساختار فیزیکی پایگاه داده رابطه‌ای (DDL)
-- هدف: ساخت جداول پایه، تعیین نوع داده‌ها، و برقراری یکپارچگی ارجاعی
-- ============================================================================

-- تنظیم انکدینگ ارتباط (Session) پایگاه داده به utf8mb4
-- این کار برای جلوگیری از بهم‌ریختگی کاراکترهای غیرانگلیسی (مثل حروف فارسی یا اسامی خاص اروپایی) الزامی است.
SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- ۱. ساخت جداول پایه (سطح اول - مستقل و بدون کلید خارجی)
-- ----------------------------------------------------------------------------

-- ساخت جدول دسته‌بندی محصولات
CREATE TABLE Categories (
    CategoryID INT PRIMARY KEY,          -- شناسه یکتای دسته‌بندی (کلید اصلی)
    CategoryName VARCHAR(50),            -- نام دسته‌بندی
    Description TEXT                     -- توضیحات تفصیلی دسته‌بندی (TEXT برای رشته‌های طولانی)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; -- استفاده از موتور InnoDB برای پشتیبانی از کلیدهای خارجی و تراکنش‌ها

-- ساخت جدول اطلاعات مشتریان
CREATE TABLE Customers (
    CustomerID VARCHAR(10) PRIMARY KEY,  -- شناسه یکتای مشتری (رشته‌ای، طبق استاندارد دیتاست Northwind)
    CompanyName VARCHAR(100),            -- نام شرکت مشتری
    ContactName VARCHAR(100),            -- نام شخص رابط
    ContactTitle VARCHAR(100),           -- سمت شخص رابط
    Address VARCHAR(255),                -- آدرس فیزیکی
    City VARCHAR(100),                   -- شهر
    Region VARCHAR(50),                  -- ایالت/منطقه
    PostalCode VARCHAR(20),              -- کد پستی
    Country VARCHAR(50),                 -- کشور
    Phone VARCHAR(50),                   -- شماره تماس تلفنی
    Fax VARCHAR(50)                      -- شماره فکس
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول اطلاعات کارکنان شرکت
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,          -- شناسه یکتای کارمند (کلید اصلی)
    LastName VARCHAR(50),                -- نام خانوادگی
    FirstName VARCHAR(50),               -- نام
    Title VARCHAR(100),                  -- سمت سازمانی
    TitleOfCourtesy VARCHAR(50),         -- عنوان احترام‌آمیز (مثل آقای/خانم)
    BirthDate DATE,                      -- تاریخ تولد (نوع داده DATE برای محاسبات زمانی)
    HireDate DATE,                       -- تاریخ استخدام
    Address VARCHAR(255),                -- آدرس محل سکونت
    City VARCHAR(100),                   -- شهر
    Region VARCHAR(50),                  -- منطقه/ایالت
    PostalCode VARCHAR(20),              -- کد پستی
    Country VARCHAR(50),                 -- کشور
    HomePhone VARCHAR(50),               -- تلفن منزل
    Extension VARCHAR(10),               -- شماره داخلی
    Notes TEXT,                          -- یادداشت‌های تکمیلی و رزومه
    ReportsTo INT,                       -- شناسه مدیری که این کارمند به او گزارش می‌دهد (رابطه خودارجاعی)
    PhotoPath VARCHAR(255)               -- مسیر ذخیره‌سازی عکس پرسنلی
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول مناطق کلان جغرافیایی
CREATE TABLE Region (
    RegionID INT PRIMARY KEY,            -- شناسه کلید اصلی منطقه
    RegionDescription VARCHAR(50)        -- نام و توضیحات منطقه
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول شرکت‌های حمل‌ونقل
CREATE TABLE Shippers (
    ShipperID INT PRIMARY KEY,           -- شناسه شرکت حمل‌ونقل
    CompanyName VARCHAR(50),             -- نام شرکت باربری
    Phone VARCHAR(50)                    -- شماره تماس
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول تامین‌کنندگان محصولات
CREATE TABLE Suppliers (
    SupplierID INT PRIMARY KEY,          -- شناسه یکتای تامین‌کننده
    CompanyName VARCHAR(100),            -- نام شرکت تامین‌کننده
    ContactName VARCHAR(100),            -- نام شخص رابط
    ContactTitle VARCHAR(100),           -- سمت شخص رابط
    Address VARCHAR(255),                -- آدرس شرکت
    City VARCHAR(100),                   -- شهر
    Region VARCHAR(50),                  -- منطقه/ایالت
    PostalCode VARCHAR(20),              -- کد پستی
    Country VARCHAR(50),                 -- کشور
    Phone VARCHAR(50),                   -- شماره تلفن
    Fax VARCHAR(50),                     -- شماره فکس
    HomePage TEXT                        -- آدرس وب‌سایت
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- ۲. ساخت جداول وابسته (سطح دوم - نیازمند کلید خارجی)
-- ----------------------------------------------------------------------------

-- ساخت جدول محصولات (وابسته به تامین‌کننده و دسته‌بندی)
CREATE TABLE Products (
    ProductID INT PRIMARY KEY,           -- شناسه یکتای محصول
    ProductName VARCHAR(100),            -- نام محصول
    SupplierID INT,                      -- کلید خارجی: شناسه تامین‌کننده
    CategoryID INT,                      -- کلید خارجی: شناسه دسته‌بندی
    QuantityPerUnit VARCHAR(50),         -- مقدار در هر واحد (مثلا 10 جعبه در هر کارتن)
    UnitPrice DECIMAL(10,2),             -- قیمت واحد (نوع داده DECIMAL برای مقادیر پولی دقیق)
    UnitsInStock INT,                    -- موجودی فعلی انبار
    UnitsOnOrder INT,                    -- تعداد در حال سفارش
    ReorderLevel INT,                    -- نقطه سفارش مجدد
    Discontinued INT                     -- وضعیت توقف تولید (معمولاً 0 یا 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول نواحی فروش (وابسته به مناطق کلان)
CREATE TABLE Territories (
    TerritoryID VARCHAR(20) PRIMARY KEY, -- شناسه یکتای ناحیه (کلید اصلی رشته‌ای)
    TerritoryDescription VARCHAR(50),    -- نام ناحیه
    RegionID INT                         -- کلید خارجی: شناسه منطقه کلان
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- ۳. ساخت جداول تراکنشی و ارتباطی چند-به-چند (سطح سوم)
-- ----------------------------------------------------------------------------

-- ساخت جدول اصلی سفارش‌ها (قلب تپنده دیتابیس تراکنشی)
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,             -- شماره یکتای سفارش (کلید اصلی)
    CustomerID VARCHAR(10),              -- کلید خارجی: مشتری ثبت‌کننده سفارش
    EmployeeID INT,                      -- کلید خارجی: کارمند مسئول سفارش
    OrderDate DATE,                      -- تاریخ ثبت سفارش
    RequiredDate DATE,                   -- تاریخ درخواستی تحویل
    ShippedDate DATE,                    -- تاریخ ارسال واقعی
    ShipVia INT,                         -- کلید خارجی: شرکت حمل‌ونقل کالا
    Freight DECIMAL(10,2),               -- هزینه حمل‌ونقل
    ShipName VARCHAR(100),               -- نام گیرنده (می‌تواند متفاوت از نام مشتری باشد)
    ShipAddress VARCHAR(255),            -- آدرس مقصد
    ShipCity VARCHAR(100),               -- شهر مقصد
    ShipRegion VARCHAR(50),              -- منطقه/ایالت مقصد
    ShipPostalCode VARCHAR(20),          -- کد پستی مقصد
    ShipCountry VARCHAR(50)              -- کشور مقصد
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول جزئیات سفارش (ارتباط چند-به-چند بین سفارش و محصول)
CREATE TABLE Order_Details (
    OrderID INT,                         -- کلید خارجی: شماره سفارش
    ProductID INT,                       -- کلید خارجی: شماره محصول
    UnitPrice DECIMAL(10,2),             -- قیمت فروش محصول در لحظه ثبت سفارش
    Quantity INT,                        -- تعداد خریداری شده
    Discount DECIMAL(4,2),               -- درصد تخفیف اعمال شده (با دو رقم اعشار)
    PRIMARY KEY (OrderID, ProductID)     -- کلید اصلی ترکیبی (Composite Primary Key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ساخت جدول ارتباطی کارکنان و نواحی فروش (ارتباط چند-به-چند)
CREATE TABLE EmployeeTerritories (
    EmployeeID INT,                      -- کلید خارجی: شناسه کارمند
    TerritoryID VARCHAR(20),             -- کلید خارجی: شناسه ناحیه
    PRIMARY KEY (EmployeeID, TerritoryID)-- کلید اصلی ترکیبی
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================================
-- ۴. افزودن قیود کلید خارجی (Foreign Keys) برای یکپارچگی ارجاعی (Referential Integrity)
-- نکته مهندسی داده: تعریف کلیدهای خارجی پس از ساخت تمام جداول (و ترجیحاً پس از
-- Import داده‌های خام CSV) انجام می‌شود تا از خطاهای قفل‌شدگی (Deadlock) جلوگیری شود.
-- ============================================================================

-- اتصال محصولات به تامین‌کنندگان و دسته‌بندی‌ها
ALTER TABLE Products
    ADD FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    ADD FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID);

-- اتصال نواحی فروش به مناطق کلان جغرافیایی
ALTER TABLE Territories
    ADD FOREIGN KEY (RegionID) REFERENCES Region(RegionID);

-- اتصال سفارش‌ها به مشتریان، کارمندان و شرکت‌های حمل‌ونقل
ALTER TABLE Orders
    ADD FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    ADD FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
    ADD FOREIGN KEY (ShipVia)    REFERENCES Shippers(ShipperID);

-- اتصال جزئیات سفارش به سفارش مادر و محصول مربوطه
ALTER TABLE Order_Details
    ADD FOREIGN KEY (OrderID)   REFERENCES Orders(OrderID),
    ADD FOREIGN KEY (ProductID) REFERENCES Products(ProductID);

-- اتصال جدول میانی مناطق کارکنان به جدول‌های کارمندان و نواحی
ALTER TABLE EmployeeTerritories
    ADD FOREIGN KEY (EmployeeID)  REFERENCES Employees(EmployeeID),
    ADD FOREIGN KEY (TerritoryID) REFERENCES Territories(TerritoryID);