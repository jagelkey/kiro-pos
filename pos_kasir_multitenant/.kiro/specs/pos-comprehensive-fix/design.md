# Design Document - Perbaikan Menyeluruh POS Kasir Multitenant

## Overview

Dokumen ini menjelaskan desain teknis untuk perbaikan menyeluruh aplikasi POS Kasir Multitenant. Perbaikan mencakup:

- Konsistensi data antara mode offline (SQLite) dan online (mock data)
- Fitur multi cabang dengan dashboard owner
- Manajemen shift kasir
- Sistem diskon dan promo
- Perbaikan bug dan peningkatan performa

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │   POS   │ │Dashboard│ │Products │ │Materials│ │ Reports │   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
└───────┼──────────┼──────────┼──────────┼──────────┼────────────┘
        │          │          │          │          │
┌───────┴──────────┴──────────┴──────────┴──────────┴────────────┐
│                      State Management (Riverpod)                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Providers│ │ Notifiers│ │  States  │ │ Computed │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
└───────┼────────────┼────────────┼────────────┼─────────────────┘
        │            │            │            │
┌───────┴────────────┴────────────┴────────────┴─────────────────┐
│                       Repository Layer                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Product  │ │ Material │ │Transaction│ │ Expense  │           │
│  │   Repo   │ │   Repo   │ │   Repo   │ │   Repo   │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
└───────┼────────────┼────────────┼────────────┼─────────────────┘
        │            │            │            │
┌───────┴────────────┴────────────┴────────────┴─────────────────┐
│                        Data Layer                               │
│  ┌─────────────────────┐    ┌─────────────────────┐            │
│  │   SQLite (Mobile)   │    │  Mock Data (Web)    │            │
│  │   DatabaseHelper    │    │    MockData         │            │
│  └─────────────────────┘    └─────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### Multi-Branch Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Owner Level                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Owner Dashboard (Aggregated View)           │    │
│  │  - Total sales across all branches                       │    │
│  │  - Branch comparison                                     │    │
│  │  - Alerts from all branches                              │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   Branch 1    │     │   Branch 2    │     │   Branch N    │
│  (Tenant A)   │     │  (Tenant B)   │     │  (Tenant N)   │
│ ┌───────────┐ │     │ ┌───────────┐ │     │ ┌───────────┐ │
│ │  Products │ │     │ │  Products │ │     │ │  Products │ │
│ │ Materials │ │     │ │ Materials │ │     │ │ Materials │ │
│ │   Users   │ │     │ │   Users   │ │     │ │   Users   │ │
│ │Transactions│ │     │ │Transactions│ │     │ │Transactions│ │
│ └───────────┘ │     │ └───────────┘ │     │ └───────────┘ │
└───────────────┘     └───────────────┘     └───────────────┘
```

## Components and Interfaces

### New Models

#### Branch Model

```dart
class Branch {
  final String id;
  final String ownerId;        // Owner yang memiliki cabang ini
  final String name;
  final String code;           // Kode unik cabang (e.g., "JKT-01")
  final String? address;
  final String? phone;
  final double taxRate;
  final bool isActive;
  final DateTime createdAt;
}
```

#### Shift Model

```dart
class Shift {
  final String id;
  final String tenantId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingCash;
  final double? closingCash;
  final double? expectedCash;
  final double? variance;
  final String? varianceNote;
  final ShiftStatus status;    // active, closed, flagged
}
```

#### Discount Model

```dart
class Discount {
  final String id;
  final String tenantId;
  final String name;
  final DiscountType type;     // percentage, fixed
  final double value;
  final double? minPurchase;
  final String? promoCode;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool isActive;
}
```

### New Repositories

#### BranchRepository

```dart
abstract class BranchRepository {
  Future<List<Branch>> getAllByOwner(String ownerId);
  Future<Branch?> getById(String id);
  Future<void> create(Branch branch);
  Future<void> update(Branch branch);
  Future<void> deactivate(String id);
}
```

#### ShiftRepository

```dart
abstract class ShiftRepository {
  Future<Shift?> getActiveShift(String tenantId, String userId);
  Future<List<Shift>> getShiftHistory(String tenantId, {DateTime? from, DateTime? to});
  Future<void> startShift(Shift shift);
  Future<void> endShift(String shiftId, double closingCash, String? note);
}
```

#### DiscountRepository

```dart
abstract class DiscountRepository {
  Future<List<Discount>> getActiveDiscounts(String tenantId);
  Future<Discount?> getByPromoCode(String tenantId, String code);
  Future<void> create(Discount discount);
  Future<void> update(Discount discount);
  Future<void> delete(String id);
}
```

### New Providers

```dart
// Branch providers
final branchesProvider = StateNotifierProvider<BranchNotifier, AsyncValue<List<Branch>>>;
final ownerDashboardProvider = StateNotifierProvider<OwnerDashboardNotifier, OwnerDashboardData>;

// Shift providers
final activeShiftProvider = StateNotifierProvider<ShiftNotifier, Shift?>;
final shiftHistoryProvider = FutureProvider<List<Shift>>;

// Discount providers
final discountsProvider = StateNotifierProvider<DiscountNotifier, AsyncValue<List<Discount>>>;
final activePromosProvider = Provider<List<Discount>>;
```

## Data Models

### Database Schema Updates

```sql
-- Branches table (untuk multi-cabang)
CREATE TABLE branches (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  address TEXT,
  phone TEXT,
  tax_rate REAL DEFAULT 0.11,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY (owner_id) REFERENCES users (id)
);

-- Shifts table (untuk manajemen shift)
CREATE TABLE shifts (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT,
  opening_cash REAL NOT NULL,
  closing_cash REAL,
  expected_cash REAL,
  variance REAL,
  variance_note TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  FOREIGN KEY (tenant_id) REFERENCES tenants (id),
  FOREIGN KEY (user_id) REFERENCES users (id)
);

-- Discounts table (untuk diskon dan promo)
CREATE TABLE discounts (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  value REAL NOT NULL,
  min_purchase REAL,
  promo_code TEXT,
  valid_from TEXT NOT NULL,
  valid_until TEXT NOT NULL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY (tenant_id) REFERENCES tenants (id)
);

-- Update transactions table untuk shift
ALTER TABLE transactions ADD COLUMN shift_id TEXT REFERENCES shifts(id);
ALTER TABLE transactions ADD COLUMN discount_id TEXT REFERENCES discounts(id);
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Cart Calculation Consistency

_For any_ cart with products and optional discount, the total SHALL equal subtotal plus tax minus discount, where tax is calculated as subtotal multiplied by tax rate.
**Validates: Requirements 4.1, 4.2**

### Property 2: Transaction Stock Update Integrity

_For any_ completed transaction, the product stock SHALL decrease by exactly the quantity sold, and material stock SHALL decrease according to recipe quantities multiplied by quantity sold.
**Validates: Requirements 4.3, 3.3**

### Property 3: Transaction ID Uniqueness

_For any_ two transactions, their IDs SHALL be different.
**Validates: Requirements 4.4**

### Property 4: Report Total Accuracy

_For any_ date range, the report total sales SHALL equal the sum of all transaction totals within that date range.
**Validates: Requirements 5.1, 5.2**

### Property 5: Profit Calculation Correctness

_For any_ period, profit SHALL equal total sales minus total expenses for that period.
**Validates: Requirements 5.3, 6.5**

### Property 6: Material Low Stock Detection

_For any_ material with minStock defined, the low stock warning SHALL be displayed if and only if current stock is less than or equal to minStock.
**Validates: Requirements 3.4**

### Property 7: Production Capacity Calculation

_For any_ product with recipe, the production capacity SHALL equal the minimum of (material stock / recipe quantity) across all materials in the recipe.
**Validates: Requirements 3.5, 8.4**

### Property 8: User Role Authorization

_For any_ user with cashier role, access to owner-only features SHALL be denied.
**Validates: Requirements 7.3**

### Property 9: Inactive User Login Prevention

_For any_ user with isActive=false, login attempt SHALL fail.
**Validates: Requirements 7.5**

### Property 10: Dashboard Data Accuracy

_For any_ dashboard view, today's sales SHALL equal sum of today's transactions, and transaction count SHALL equal count of today's transactions.
**Validates: Requirements 8.1, 8.2, 8.3**

### Property 11: Branch Data Isolation

_For any_ user assigned to a branch, queries SHALL only return data where tenant_id matches the user's assigned branch.
**Validates: Requirements 11.4**

### Property 12: Owner Dashboard Aggregation

_For any_ owner viewing dashboard, total sales SHALL equal sum of sales across all branches owned by that owner.
**Validates: Requirements 12.1, 12.2**

### Property 13: Shift Cash Calculation

_For any_ closed shift, expected cash SHALL equal opening cash plus sum of cash transactions during that shift.
**Validates: Requirements 13.2**

### Property 14: Shift Transaction Association

_For any_ transaction created during an active shift, the transaction SHALL have shift_id set to the active shift's ID.
**Validates: Requirements 13.5**

### Property 15: Percentage Discount Calculation

_For any_ percentage discount applied to a cart, the discount amount SHALL equal subtotal multiplied by (discount value / 100).
**Validates: Requirements 14.2**

### Property 16: Fixed Discount Calculation

_For any_ fixed discount applied to a cart, the discount amount SHALL equal the discount value (capped at subtotal).
**Validates: Requirements 14.3**

### Property 17: Discount Validity Period

_For any_ discount with validity period, the discount SHALL only be applicable if current date is between validFrom and validUntil inclusive.
**Validates: Requirements 14.4**

### Property 18: Minimum Purchase Validation

_For any_ discount with minPurchase requirement, the discount SHALL only be applicable if cart subtotal is greater than or equal to minPurchase.
**Validates: Requirements 14.5**

### Property 19: Promo Code Validation

_For any_ valid promo code, applying the code SHALL result in the corresponding discount being applied to the cart.
**Validates: Requirements 14.6**

### Property 20: CRUD Persistence Round-Trip

_For any_ entity (product, material, expense, user, discount), creating then reading SHALL return an equivalent entity.
**Validates: Requirements 2.1, 2.2, 3.1, 6.1, 7.1, 14.1**

## Error Handling

### Database Errors

- All repository methods wrapped in try-catch
- Errors propagated to UI via AsyncValue.error
- User-friendly error messages displayed
- Retry mechanism for transient failures

### Validation Errors

- Form validation before submission
- Required field checks
- Type validation (numbers, dates)
- Business rule validation (e.g., stock cannot be negative)

### Network Errors (Future)

- Offline detection
- Queue operations for sync
- Conflict resolution strategy

## Testing Strategy

### Unit Testing

- Model serialization/deserialization
- Repository CRUD operations
- Business logic calculations (cart, discount, profit)
- Date filtering logic

### Property-Based Testing

Using `dart_quickcheck` or `glados` package for property-based testing:

- **Cart calculations**: Generate random products and quantities, verify total calculation
- **Stock updates**: Generate random transactions, verify stock decreases correctly
- **Discount calculations**: Generate random discounts and carts, verify discount amounts
- **Date filtering**: Generate random date ranges and transactions, verify filtering
- **Data isolation**: Generate random users and branches, verify data isolation

### Integration Testing

- Full transaction flow (add to cart → checkout → verify stock)
- Shift management flow (start → transactions → end → verify cash)
- Multi-branch data aggregation

### Test Configuration

- Minimum 100 iterations per property test
- Each property test tagged with format: `**Feature: pos-comprehensive-fix, Property {number}: {property_text}**`
