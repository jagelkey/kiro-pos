# Requirements Document

## Introduction

Dokumen ini mendefinisikan requirements untuk perbaikan komprehensif halaman Dashboard pada aplikasi POS Kasir Multitenant. Dashboard adalah halaman utama yang menampilkan ringkasan bisnis harian termasuk penjualan, transaksi, laba, kapasitas produksi, dan peringatan stok rendah. Perbaikan ini fokus pada:

1. Memastikan semua fitur berfungsi di mode offline dan online
2. Integrasi real-time dengan Supabase
3. Dukungan penuh untuk arsitektur multi-tenant dengan isolasi data per tenant dan branch

## Glossary

- **Dashboard**: Halaman utama aplikasi yang menampilkan ringkasan data bisnis
- **Tenant**: Entitas bisnis utama (pemilik usaha) yang memiliki data terpisah
- **Branch**: Cabang dari tenant yang dapat memiliki data terpisah
- **Offline Mode**: Mode operasi tanpa koneksi internet menggunakan SQLite lokal
- **Online Mode**: Mode operasi dengan koneksi internet menggunakan Supabase
- **Real-time Sync**: Sinkronisasi data otomatis saat ada perubahan di database
- **Production Capacity**: Jumlah produk yang dapat diproduksi berdasarkan stok bahan baku
- **Low Stock Warning**: Peringatan ketika stok bahan baku di bawah minimum
- **Gross Profit**: Laba kotor (penjualan - harga pokok penjualan)
- **Net Profit**: Laba bersih (penjualan - biaya operasional)

## Requirements

### Requirement 1: Data Loading dan Error Handling

**User Story:** As a user, I want the dashboard to load data reliably and show clear error messages, so that I can understand the current state of my business.

#### Acceptance Criteria

1. WHEN the dashboard screen loads THEN the Dashboard SHALL display a loading indicator while fetching data
2. WHEN data loading fails THEN the Dashboard SHALL display a user-friendly error message with retry option
3. WHEN the user taps the refresh button THEN the Dashboard SHALL reload all data from the appropriate source (local or cloud)
4. WHEN tenant information is not available THEN the Dashboard SHALL display an empty state without crashing
5. IF tenant ID is empty or invalid THEN the Dashboard SHALL display an appropriate error message

### Requirement 2: Multi-Tenant Data Isolation

**User Story:** As a tenant owner, I want to see only my business data on the dashboard, so that my data is secure and separate from other tenants.

#### Acceptance Criteria

1. WHEN loading dashboard data THEN the Dashboard SHALL filter all queries by the current tenant ID
2. WHEN a user belongs to a specific branch THEN the Dashboard SHALL filter data by both tenant ID and branch ID
3. WHEN calculating sales totals THEN the Dashboard SHALL only include transactions from the current tenant
4. WHEN displaying production capacity THEN the Dashboard SHALL only consider materials and products from the current tenant
5. WHEN showing low stock warnings THEN the Dashboard SHALL only display materials from the current tenant

### Requirement 3: Offline Mode Support

**User Story:** As a cashier, I want the dashboard to work without internet connection, so that I can continue operating during network outages.

#### Acceptance Criteria

1. WHEN the device is offline THEN the Dashboard SHALL load data from local SQLite database
2. WHEN Supabase connection fails THEN the Dashboard SHALL fallback to local data without showing error
3. WHEN operating in offline mode THEN the Dashboard SHALL display all statistics from local transactions
4. WHEN the device reconnects THEN the Dashboard SHALL sync pending data and refresh display
5. WHEN web platform is used without Supabase THEN the Dashboard SHALL use mock data for demonstration

### Requirement 4: Online Mode with Supabase Integration

**User Story:** As a business owner, I want the dashboard to show real-time data from cloud, so that I can monitor my business from anywhere.

#### Acceptance Criteria

1. WHEN Supabase is enabled and connected THEN the Dashboard SHALL fetch data from cloud database
2. WHEN new transactions are created THEN the Dashboard SHALL update sales totals in real-time
3. WHEN material stock changes THEN the Dashboard SHALL update production capacity and low stock warnings
4. WHEN expenses are added THEN the Dashboard SHALL recalculate profit figures
5. WHEN cloud data fetch fails THEN the Dashboard SHALL fallback to local data gracefully

### Requirement 5: Sales Statistics Accuracy

**User Story:** As a business owner, I want accurate sales statistics, so that I can make informed business decisions.

#### Acceptance Criteria

1. WHEN displaying today's sales THEN the Dashboard SHALL calculate sum of all transaction totals for current date
2. WHEN displaying transaction count THEN the Dashboard SHALL show exact number of transactions for current date
3. WHEN calculating gross profit THEN the Dashboard SHALL subtract cost of goods sold from total sales
4. WHEN calculating net profit THEN the Dashboard SHALL subtract daily expenses from gross profit
5. WHEN displaying profit margin THEN the Dashboard SHALL show percentage with one decimal precision

### Requirement 6: Production Capacity Display

**User Story:** As a production manager, I want to see which products can be made with current stock, so that I can plan production efficiently.

#### Acceptance Criteria

1. WHEN products have recipes defined THEN the Dashboard SHALL calculate production capacity based on material stock
2. WHEN a material is out of stock THEN the Dashboard SHALL mark affected products as "out of stock"
3. WHEN displaying capacity counts THEN the Dashboard SHALL show separate counts for producible and out-of-stock products
4. WHEN a product has no recipe THEN the Dashboard SHALL exclude it from production capacity calculation
5. WHEN material stock is insufficient THEN the Dashboard SHALL identify the limiting material

### Requirement 7: Low Stock Warning System

**User Story:** As an inventory manager, I want to be alerted when materials are running low, so that I can reorder before running out.

#### Acceptance Criteria

1. WHEN material stock falls below minimum threshold THEN the Dashboard SHALL display a warning indicator
2. WHEN multiple materials are low THEN the Dashboard SHALL show total count of low stock items
3. WHEN user taps the warning THEN the Dashboard SHALL provide navigation hint to materials screen
4. WHEN no materials are low THEN the Dashboard SHALL hide the warning section
5. WHEN minimum stock is not set for a material THEN the Dashboard SHALL exclude it from low stock calculation

### Requirement 8: Recent Transactions Display

**User Story:** As a cashier, I want to see recent transactions, so that I can quickly verify recent sales.

#### Acceptance Criteria

1. WHEN transactions exist THEN the Dashboard SHALL display up to 5 most recent transactions
2. WHEN displaying a transaction THEN the Dashboard SHALL show item count, payment method, total, and time
3. WHEN no transactions exist THEN the Dashboard SHALL display an empty state message
4. WHEN transaction time is recent THEN the Dashboard SHALL show relative time (e.g., "5m ago")
5. WHEN transaction time is older than 24 hours THEN the Dashboard SHALL show date format

### Requirement 9: Real-time Data Updates

**User Story:** As a business owner, I want the dashboard to update automatically when data changes, so that I always see current information.

#### Acceptance Criteria

1. WHEN a new transaction is created elsewhere THEN the Dashboard SHALL refresh data automatically
2. WHEN material stock is updated THEN the Dashboard SHALL recalculate production capacity
3. WHEN an expense is added THEN the Dashboard SHALL update profit calculations
4. WHEN real-time subscription fails THEN the Dashboard SHALL continue with manual refresh capability
5. WHEN user pulls to refresh THEN the Dashboard SHALL reload all data from source

### Requirement 10: Responsive Layout

**User Story:** As a user, I want the dashboard to display properly on different screen sizes, so that I can use it on phone, tablet, or desktop.

#### Acceptance Criteria

1. WHEN screen width is mobile size THEN the Dashboard SHALL display 2-column grid for statistics
2. WHEN screen width is tablet or larger THEN the Dashboard SHALL display 4-column grid for statistics
3. WHEN displaying stat cards THEN the Dashboard SHALL adjust aspect ratio based on screen size
4. WHEN text overflows THEN the Dashboard SHALL truncate with ellipsis
5. WHEN scrolling THEN the Dashboard SHALL support pull-to-refresh gesture
