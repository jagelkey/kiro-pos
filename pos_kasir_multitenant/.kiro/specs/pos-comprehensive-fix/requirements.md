# Requirements Document - Perbaikan Menyeluruh POS Kasir Multitenant

## Introduction

Dokumen ini berisi requirements untuk perbaikan menyeluruh aplikasi POS Kasir Multitenant agar semua fitur berfungsi 100% sesuai role bisnis aplikasi coffee shop. Perbaikan mencakup fungsionalitas offline/online, konsistensi data, dan peningkatan UX.

## Glossary

- **POS**: Point of Sale - sistem kasir untuk transaksi penjualan
- **Tenant**: Entitas bisnis/toko yang menggunakan aplikasi
- **Branch**: Cabang toko yang merupakan bagian dari satu bisnis owner
- **Material**: Bahan baku yang digunakan untuk membuat produk
- **Recipe**: Resep yang menghubungkan produk dengan bahan baku yang dibutuhkan
- **Stock Movement**: Pencatatan pergerakan stok (masuk/keluar)
- **Offline Mode**: Mode operasi tanpa koneksi internet menggunakan SQLite lokal
- **Online Mode**: Mode operasi dengan koneksi internet (web) menggunakan mock data
- **Shift**: Periode kerja kasir dengan pencatatan kas awal dan akhir
- **Cash Variance**: Selisih antara kas yang diharapkan dengan kas aktual pada akhir shift
- **Discount**: Potongan harga yang dapat berupa persentase atau nominal tetap
- **Promo Code**: Kode unik yang dapat dimasukkan untuk mendapatkan diskon

## Requirements

### Requirement 1: Sinkronisasi Data Offline/Online

**User Story:** As a kasir, I want to use the application both offline and online, so that I can continue operations regardless of internet connectivity.

#### Acceptance Criteria

1. WHEN the application runs on mobile/desktop platform THEN the POS_System SHALL use SQLite database for data persistence
2. WHEN the application runs on web platform THEN the POS_System SHALL use in-memory mock data with localStorage backup
3. WHEN a transaction is completed in offline mode THEN the POS_System SHALL store the transaction locally and mark it for sync
4. WHEN the application detects internet connectivity THEN the POS_System SHALL attempt to sync pending transactions
5. WHEN data is modified locally THEN the POS_System SHALL update the local database immediately without requiring network

### Requirement 2: Manajemen Produk yang Konsisten

**User Story:** As a store owner, I want to manage products with complete CRUD operations, so that I can maintain accurate product catalog.

#### Acceptance Criteria

1. WHEN a user creates a new product THEN the POS_System SHALL validate required fields (name, price, stock) and save to database
2. WHEN a user updates a product THEN the POS_System SHALL persist changes to the appropriate storage (SQLite or mock data)
3. WHEN a user deletes a product THEN the POS_System SHALL remove the product and update related references
4. WHEN displaying products THEN the POS_System SHALL show accurate stock levels from the database
5. WHEN a product has an image THEN the POS_System SHALL store and display the image correctly in base64 format

### Requirement 3: Manajemen Bahan Baku dengan Integrasi Resep

**User Story:** As a store manager, I want to manage raw materials and see their usage in recipes, so that I can plan inventory effectively.

#### Acceptance Criteria

1. WHEN a user creates a new material THEN the POS_System SHALL validate required fields (name, stock, unit) and save to database
2. WHEN a user updates material stock THEN the POS_System SHALL record the stock movement with timestamp and reason
3. WHEN a transaction is completed THEN the POS_System SHALL automatically reduce material stock based on product recipes
4. WHEN material stock falls below minimum threshold THEN the POS_System SHALL display a visual warning indicator
5. WHEN viewing a material THEN the POS_System SHALL show which products use that material and estimated production capacity

### Requirement 4: Transaksi POS yang Lengkap

**User Story:** As a kasir, I want to process sales transactions with all payment methods, so that I can serve customers efficiently.

#### Acceptance Criteria

1. WHEN a user adds products to cart THEN the POS_System SHALL calculate subtotal, tax, and total correctly
2. WHEN a user applies discount THEN the POS_System SHALL recalculate total with discount applied
3. WHEN a user completes checkout THEN the POS_System SHALL save transaction, update product stock, and update material stock
4. WHEN a transaction is saved THEN the POS_System SHALL generate a unique transaction ID and timestamp
5. WHEN displaying receipt THEN the POS_System SHALL show complete transaction details including items, prices, tax, and payment method

### Requirement 5: Laporan dan Analitik yang Akurat

**User Story:** As a store owner, I want to view accurate sales reports, so that I can make informed business decisions.

#### Acceptance Criteria

1. WHEN viewing reports THEN the POS_System SHALL calculate totals from actual transaction data in database
2. WHEN filtering by date range THEN the POS_System SHALL display only transactions within the selected period
3. WHEN displaying profit/loss THEN the POS_System SHALL calculate based on actual sales minus actual expenses
4. WHEN showing product performance THEN the POS_System SHALL aggregate sales data by product from transactions
5. WHEN exporting reports THEN the POS_System SHALL generate accurate data in the selected format (PDF/Excel)

### Requirement 6: Manajemen Biaya Operasional

**User Story:** As a store owner, I want to track operational expenses, so that I can monitor business costs.

#### Acceptance Criteria

1. WHEN a user creates an expense THEN the POS_System SHALL validate required fields (category, amount, date) and save to database
2. WHEN a user updates an expense THEN the POS_System SHALL persist changes to the appropriate storage
3. WHEN a user deletes an expense THEN the POS_System SHALL remove the expense from database
4. WHEN viewing expenses THEN the POS_System SHALL display accurate totals grouped by category and time period
5. WHEN calculating profit THEN the POS_System SHALL subtract total expenses from total sales

### Requirement 7: Manajemen Pengguna dengan Role-Based Access

**User Story:** As a store owner, I want to manage users with different roles, so that I can control access to features.

#### Acceptance Criteria

1. WHEN a user creates a new user THEN the POS_System SHALL validate required fields and save to database
2. WHEN a user updates user status THEN the POS_System SHALL persist the active/inactive status
3. WHEN a user with cashier role logs in THEN the POS_System SHALL restrict access to owner-only features
4. WHEN displaying users THEN the POS_System SHALL show accurate count by role and status
5. WHEN a user is deactivated THEN the POS_System SHALL prevent that user from logging in

### Requirement 8: Dashboard dengan Data Real-Time

**User Story:** As a store manager, I want to see real-time dashboard metrics, so that I can monitor daily operations.

#### Acceptance Criteria

1. WHEN viewing dashboard THEN the POS_System SHALL display today's sales calculated from actual transactions
2. WHEN viewing dashboard THEN the POS_System SHALL display transaction count from actual database records
3. WHEN viewing dashboard THEN the POS_System SHALL display recent transactions from database
4. WHEN viewing dashboard THEN the POS_System SHALL display production capacity based on current material stock
5. WHEN a new transaction is completed THEN the POS_System SHALL refresh dashboard data automatically

### Requirement 9: Pengaturan Toko yang Persisten

**User Story:** As a store owner, I want to configure store settings, so that I can customize the application for my business.

#### Acceptance Criteria

1. WHEN a user updates store information THEN the POS_System SHALL persist changes to tenant record
2. WHEN a user changes tax rate THEN the POS_System SHALL apply new rate to subsequent transactions
3. WHEN a user configures printer settings THEN the POS_System SHALL save preferences locally
4. WHEN the application restarts THEN the POS_System SHALL restore previously saved settings
5. WHEN a user logs out THEN the POS_System SHALL clear session but preserve tenant settings

### Requirement 10: Cetak Struk yang Berfungsi

**User Story:** As a kasir, I want to print receipts, so that I can provide transaction proof to customers.

#### Acceptance Criteria

1. WHEN a user clicks print receipt THEN the POS_System SHALL generate a formatted receipt document
2. WHEN printing on web platform THEN the POS_System SHALL use browser print dialog
3. WHEN printing on mobile platform THEN the POS_System SHALL support Bluetooth thermal printer
4. WHEN generating receipt THEN the POS_System SHALL include store info, items, totals, and transaction details
5. WHEN auto-print is enabled THEN the POS_System SHALL automatically print after successful transaction

### Requirement 11: Manajemen Multi Cabang

**User Story:** As a business owner, I want to manage multiple store branches, so that I can expand my business while maintaining centralized control.

#### Acceptance Criteria

1. WHEN an owner creates a new branch THEN the POS_System SHALL create a new tenant record with unique identifier and branch details
2. WHEN viewing branches THEN the POS_System SHALL display list of all branches with their status and basic metrics
3. WHEN a branch is created THEN the POS_System SHALL allow configuration of branch-specific settings (address, phone, tax rate)
4. WHEN a user is assigned to a branch THEN the POS_System SHALL restrict that user's data access to their assigned branch only
5. WHEN a branch is deactivated THEN the POS_System SHALL prevent new transactions but preserve historical data

### Requirement 12: Dashboard Owner Multi Cabang

**User Story:** As a business owner, I want to view consolidated dashboard across all branches, so that I can monitor overall business performance.

#### Acceptance Criteria

1. WHEN an owner views the owner dashboard THEN the POS_System SHALL display aggregated sales from all branches
2. WHEN viewing branch comparison THEN the POS_System SHALL show sales, transactions, and profit per branch side by side
3. WHEN filtering by date range THEN the POS_System SHALL apply the filter to all branch data simultaneously
4. WHEN viewing branch details THEN the POS_System SHALL allow drill-down to individual branch metrics
5. WHEN a branch has alerts (low stock, low sales) THEN the POS_System SHALL display notifications on the owner dashboard

### Requirement 13: Manajemen Shift Kasir

**User Story:** As a store manager, I want to manage cashier shifts, so that I can track accountability and cash reconciliation.

#### Acceptance Criteria

1. WHEN a kasir starts a shift THEN the POS_System SHALL record shift start time and opening cash amount
2. WHEN a kasir ends a shift THEN the POS_System SHALL calculate expected cash based on transactions and compare with actual cash
3. WHEN viewing shift history THEN the POS_System SHALL display all shifts with start time, end time, total sales, and cash variance
4. WHEN a shift has cash variance THEN the POS_System SHALL flag the shift and require explanation note
5. WHEN a kasir is on active shift THEN the POS_System SHALL associate all transactions with that shift record

### Requirement 14: Fitur Diskon dan Promo

**User Story:** As a store owner, I want to create discounts and promotions, so that I can attract customers and increase sales.

#### Acceptance Criteria

1. WHEN an owner creates a discount THEN the POS_System SHALL save discount details (name, type, value, validity period)
2. WHEN a discount is percentage-based THEN the POS_System SHALL calculate discount as percentage of subtotal
3. WHEN a discount is fixed-amount THEN the POS_System SHALL subtract fixed amount from subtotal
4. WHEN a discount has validity period THEN the POS_System SHALL only allow application within valid dates
5. WHEN a discount has minimum purchase requirement THEN the POS_System SHALL validate cart total before applying discount
6. WHEN a promo code is entered THEN the POS_System SHALL validate the code and apply corresponding discount
7. WHEN viewing active promotions THEN the POS_System SHALL display list of currently valid discounts and promos
