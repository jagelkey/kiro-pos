# Implementation Plan - Perbaikan Menyeluruh POS Kasir Multitenant

## Phase 1: Core Data Layer Fixes

- [x] 1. Fix Data Persistence Consistency

  - [x] 1.1 Update ProductRepository to handle both SQLite and MockData consistently

    - Ensure create, update, delete operations work identically on both platforms
    - Add proper error handling and return values
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 1.2 Update MaterialRepository for consistent CRUD operations

    - Fix stock update to record stock movements
    - Ensure material stock changes are persisted correctly
    - _Requirements: 3.1, 3.2_

  - [x] 1.3 Update ExpenseRepository for consistent CRUD operations

    - Ensure date filtering works correctly
    - Fix category grouping logic
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 1.4 Update TransactionRepository for consistent operations

    - Ensure transaction items are serialized/deserialized correctly

    - Fix date range queries
    - _Requirements: 4.3, 4.4_

  - [x] 1.5 Write property test for CRUD persistence round-trip

    - **Property 20: CRUD Persistence Round-Trip**
    - **Validates: Requirements 2.1, 2.2, 3.1, 6.1, 7.1, 14.1**

- [x] 2. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 2: Transaction and Stock Management

- [x] 3. Fix POS Transaction Flow

  - [x] 3.1 Fix cart calculation logic in PosScreen

    - Ensure subtotal, tax, and total are calculated correctly
    - Handle discount application properly
    - _Requirements: 4.1, 4.2_

  - [x] 3.2 Write property test for cart calculation

    - **Property 1: Cart Calculation Consistency**

    - **Validates: Requirements 4.1, 4.2**

  - [x] 3.3 Fix stock update on checkout

    - Update product stock correctly after transaction
    - Update material stock based on recipe

    - _Requirements: 4.3, 3.3_

  - [x] 3.4 Write property test for transaction stock update

    - **Property 2: Transaction Stock Update Integrity**
    - **Validates: Requirements 4.3, 3.3**

  - [x] 3.5 Ensure transaction ID uniqueness

    - Verify UUID generation is working correctly
    - _Requirements: 4.4_

  - [x] 3.6 Write property test for transaction ID uniqueness

    - **Property 3: Transaction ID Uniqueness**

    - **Validates: Requirements 4.4**

- [x] 4. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 3: Dashboard and Reports

- [x] 5. Fix Dashboard Data Accuracy

  - [x] 5.1 Update DashboardProvider to fetch real data

    - Calculate today's sales from actual transactions
    - Get transaction count from database
    - Fetch recent transactions correctly
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 5.2 Write property test for dashboard data accuracy

    - **Property 10: Dashboard Data Accuracy**

    - **Validates: Requirements 8.1, 8.2, 8.3**

  - [x] 5.3 Fix production capacity calculation

    - Calculate based on material stock and recipes
    - Show correct "can produce" vs "out of stock" counts
    - _Requirements: 8.4, 3.5_

  - [x] 5.4 Write property test for production capacity

    - **Property 7: Production Capacity Calculation**
    - **Validates: Requirements 3.5, 8.4**

- [x] 6. Fix Reports Accuracy

  - [x] 6.1 Update ReportsProvider to calculate from real data

    - Fix total sales calculation

    - Fix expense totals
    - Fix profit calculation
    - _Requirements: 5.1, 5.3_

  - [x] 6.2 Write property test for report totals

    - **Property 4: Report Total Accuracy**
    - **Validates: Requirements 5.1, 5.2**

  - [x] 6.3 Write property test for profit calculation

    - **Property 5: Profit Calculation Correctness**
    - **Validates: Requirements 5.3, 6.5**

  - [x] 6.4 Fix date range filtering in reports

    - Ensure transactions are filtered correctly by date

    - _Requirements: 5.2_

- [x] 7. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 4: Material Management

- [x] 8. Fix Material Stock Management

  - [x] 8.1 Fix low stock detection and display

    - Show warning when stock <= minStock

    - Update visual indicators
    - _Requirements: 3.4_

  - [x] 8.2 Write property test for low stock detection

    - **Property 6: Material Low Stock Detection**
    - **Validates: Requirements 3.4**

  - [x] 8.3 Fix stock movement recording

    - Record all stock changes with timestamp and reason
    - _Requirements: 3.2_

- [x] 9. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 5: User Management and Authorization

- [x] 10. Fix User Management

  - [x] 10.1 Update UserRepository for consistent CRUD

    - Ensure user creation validates required fields
    - Fix status toggle persistence
    - _Requirements: 7.1, 7.2_

  - [x] 10.2 Implement role-based access control

    - Restrict owner-only features for cashier role
    - _Requirements: 7.3_

  - [x] 10.3 Write property test for role authorization

    - **Property 8: User Role Authorization**
    - **Validates: Requirements 7.3**

  - [x] 10.4 Fix inactive user login prevention

    - Check isActive status during login
    - _Requirements: 7.5_

  - [x] 10.5 Write property test for inactive user login

    - **Property 9: Inactive User Login Prevention**
    - **Validates: Requirements 7.5**

- [x] 11. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 6: New Feature - Shift Management

- [x] 12. Implement Shift Model and Repository

  - [x] 12.1 Create Shift model class

    - Define all fields: id, tenantId, userId, startTime, endTime, openingCash, closingCash, expectedCash, variance, varianceNote, status
    - Implement toMap, fromMap, toJson, fromJson
    - _Requirements: 13.1_

  - [x] 12.2 Create ShiftRepository

    - Implement getActiveShift, getShiftHistory, startShift, endShift
    - Handle both SQLite and MockData
    - _Requirements: 13.1, 13.2, 13.3_

  - [x] 12.3 Update database schema for shifts table

    - Add shifts table to DatabaseHelper
    - Add shift_id column to transactions table
    - _Requirements: 13.5_

- [x] 13. Implement Shift Provider and UI

  - [x] 13.1 Create ShiftProvider

    - Manage active shift state
    - Calculate expected cash on shift end
    - _Requirements: 13.2_

  - [x] 13.2 Write property test for shift cash calculation

    - **Property 13: Shift Cash Calculation**
    - **Validates: Requirements 13.2**

  - [x] 13.3 Create ShiftScreen UI

    - Start shift dialog with opening cash input
    - End shift dialog with closing cash and variance display
    - Shift history list
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [x] 13.4 Integrate shift with POS transactions

    - Associate transactions with active shift
    - _Requirements: 13.5_

  - [x] 13.5 Write property test for shift-transaction association

    - **Property 14: Shift Transaction Association**
    - **Validates: Requirements 13.5**

- [x] 14. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 7: New Feature - Discount and Promo

- [x] 15. Implement Discount Model and Repository

  - [x] 15.1 Create Discount model class

    - Define all fields: id, tenantId, name, type, value, minPurchase, promoCode, validFrom, validUntil, isActive
    - Implement toMap, fromMap, toJson, fromJson
    - _Requirements: 14.1_

  - [x] 15.2 Create DiscountRepository

    - Implement getActiveDiscounts, getByPromoCode, create, update, delete
    - Handle both SQLite and MockData
    - _Requirements: 14.1, 14.6, 14.7_

  - [x] 15.3 Update database schema for discounts table

    - Add discounts table to DatabaseHelper
    - Add discount_id column to transactions table
    - _Requirements: 14.1_

- [x] 16. Implement Discount Logic

  - [x] 16.1 Create DiscountProvider

    - Manage discounts list

    - Filter active discounts by date
    - _Requirements: 14.7_

  - [x] 16.2 Implement discount calculation logic

    - Percentage discount calculation
    - Fixed amount discount calculation
    - _Requirements: 14.2, 14.3_

  - [x] 16.3 Write property test for percentage discount

    - **Property 15: Percentage Discount Calculation**
    - **Validates: Requirements 14.2**

  - [x] 16.4 Write property test for fixed discount
    - **Property 16: Fixed Discount Calculation**
    - **Validates: Requirements 14.3**
  - [x] 16.5 Implement discount validation

    - Validity period check
    - Minimum purchase check
    - _Requirements: 14.4, 14.5_

  - [x] 16.6 Write property test for discount validity
    - **Property 17: Discount Validity Period**
    - **Validates: Requirements 14.4**
  - [x] 16.7 Write property test for minimum purchase
    - **Property 18: Minimum Purchase Validation**
    - **Validates: Requirements 14.5**

- [x] 17. Implement Discount UI

  - [x] 17.1 Create DiscountManagementScreen

    - List all discounts
    - Create/edit/delete discount forms
    - _Requirements: 14.1, 14.7_

  - [x] 17.2 Integrate discount with POS

    - Promo code input field
    - Discount selection dropdown
    - Apply discount to cart
    - _Requirements: 14.6_

  - [x] 17.3 Write property test for promo code validation
    - **Property 19: Promo Code Validation**
    - **Validates: Requirements 14.6**

- [x] 18. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 8: New Feature - Multi Branch

- [x] 19. Implement Branch Model and Repository

  - [x] 19.1 Create Branch model class

    - Define all fields: id, ownerId, name, code, address, phone, taxRate, isActive, createdAt
    - Implement toMap, fromMap, toJson, fromJson
    - _Requirements: 11.1, 11.3_

  - [x] 19.2 Create BranchRepository

    - Implement getAllByOwner, getById, create, update, deactivate
    - Handle both SQLite and MockData
    - _Requirements: 11.1, 11.2, 11.5_

  - [x] 19.3 Update database schema for branches table

    - Add branches table to DatabaseHelper
    - _Requirements: 11.1_

- [x] 20. Implement Branch Data Isolation

  - [x] 20.1 Update all repositories to filter by tenant_id

    - Ensure data queries include tenant_id filter
    - _Requirements: 11.4_

  - [x] 20.2 Write property test for branch data isolation
    - **Property 11: Branch Data Isolation**
    - **Validates: Requirements 11.4**

- [x] 21. Implement Branch Management UI

  - [x] 21.1 Create BranchManagementScreen

    - List all branches for owner
    - Create/edit branch forms
    - Activate/deactivate branch
    - _Requirements: 11.1, 11.2, 11.3, 11.5_

- [x] 22. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 9: Owner Dashboard

- [x] 23. Implement Owner Dashboard

  - [x] 23.1 Create OwnerDashboardProvider

    - Aggregate sales across all branches

    - Calculate per-branch metrics
    - _Requirements: 12.1, 12.2_

  - [x] 23.2 Write property test for owner dashboard aggregation
    - **Property 12: Owner Dashboard Aggregation**
    - **Validates: Requirements 12.1, 12.2**
  - [x] 23.3 Create OwnerDashboardScreen

    - Total sales card
    - Branch comparison chart
    - Branch alerts section
    - _Requirements: 12.1, 12.2, 12.5_

  - [x] 23.4 Implement date range filter for owner dashboard

    - Apply filter to all branch data
    - _Requirements: 12.3_

- [x] 24. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 10: Settings and Receipt Printing

- [x] 25. Fix Settings Persistence

  - [x] 25.1 Update SettingsScreen to persist changes

    - Save store info changes to tenant record
    - Save tax rate changes
    - _Requirements: 9.1, 9.2_

  - [x] 25.2 Implement local settings storage

    - Save printer settings to SharedPreferences
    - Restore settings on app start
    - _Requirements: 9.3, 9.4_

  - [x] 25.3 Fix logout to preserve tenant settings

    - Clear session but keep tenant data

    - _Requirements: 9.5_

- [x] 26. Fix Receipt Printing

  - [x] 26.1 Update ReceiptPrinter service

    - Generate complete receipt with all required info
    - Support web browser print
    - _Requirements: 10.1, 10.2, 10.4_

  - [x] 26.2 Add auto-print setting

    - Check setting before auto-printing
    - _Requirements: 10.5_

- [x] 27. Final Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

## Phase 11: Documentation

- [x] 28. Update Documentation

  - [x] 28.1 Update ANALYSIS_REPORT.md with fixes made

  - [x] 28.2 Update FINAL_STATUS.md with new features

  - [x] 28.3 Create DEVELOPMENT_SUGGESTIONS.md with future recommendations

  - [x] 28.4 Update DATABASE_SCHEMA.md with new tables
