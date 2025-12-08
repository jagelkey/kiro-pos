-- Migration: Add unique constraint for active shifts
-- Prevents multiple active shifts per user
-- Date: 2024-12-08

-- Create unique index for one active shift per user per tenant
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_shift_per_user
ON shifts(user_id, tenant_id)
WHERE status = 'active';

-- Add check constraint for opening cash (must be non-negative)
-- Note: SQLite doesn't support adding constraints to existing tables
-- This would need to be applied during table creation or via recreation

-- For reference, the constraint would be:
-- CHECK (opening_cash >= 0)
-- CHECK (closing_cash >= 0 OR closing_cash IS NULL)
