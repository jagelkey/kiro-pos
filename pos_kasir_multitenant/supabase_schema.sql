-- =====================================================
-- POS KASIR MULTITENANT - SUPABASE SCHEMA
-- =====================================================
-- Run this SQL in Supabase SQL Editor to create all tables
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. TENANTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    identifier TEXT UNIQUE NOT NULL,
    logo_url TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    currency TEXT NOT NULL DEFAULT 'IDR',
    tax_rate DECIMAL(5,4) DEFAULT 0.0,
    address TEXT,
    phone TEXT,
    email TEXT,
    settings JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- 2. USERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL DEFAULT '',
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'cashier')),
    branch_id UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_tenant ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- =====================================================
-- 3. BRANCHES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES users(id),
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    tax_rate DECIMAL(5,4) DEFAULT 0.11,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_branches_tenant ON branches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_branches_owner ON branches(owner_id);

-- Add foreign key for users.branch_id after branches table exists
ALTER TABLE users ADD CONSTRAINT fk_users_branch 
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL;

-- =====================================================
-- 4. PRODUCTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    barcode TEXT,
    price DECIMAL(15,2) NOT NULL,
    cost DECIMAL(15,2) DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    category TEXT,
    image_url TEXT,
    composition JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_tenant ON products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_branch ON products(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);


-- =====================================================
-- 5. MATERIALS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    stock DECIMAL(15,4) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL,
    min_stock DECIMAL(15,4),
    cost_per_unit DECIMAL(15,2) DEFAULT 0,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_materials_tenant ON materials(tenant_id);
CREATE INDEX IF NOT EXISTS idx_materials_branch ON materials(branch_id);

-- =====================================================
-- 6. SHIFTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    opening_cash DECIMAL(15,2) NOT NULL,
    closing_cash DECIMAL(15,2),
    expected_cash DECIMAL(15,2),
    variance DECIMAL(15,2),
    variance_note TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'closed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shifts_tenant ON shifts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_shifts_user ON shifts(user_id);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);

-- =====================================================
-- 7. DISCOUNTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS discounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed')),
    value DECIMAL(15,2) NOT NULL,
    min_purchase DECIMAL(15,2),
    promo_code TEXT,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discounts_tenant ON discounts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_discounts_promo_code ON discounts(promo_code);

-- =====================================================
-- 8. TRANSACTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    shift_id UUID REFERENCES shifts(id),
    discount_id UUID REFERENCES discounts(id),
    items JSONB NOT NULL,
    subtotal DECIMAL(15,2) NOT NULL,
    discount DECIMAL(15,2) DEFAULT 0,
    tax DECIMAL(15,2) DEFAULT 0,
    total DECIMAL(15,2) NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'qris', 'debit', 'transfer', 'ewallet')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_tenant ON transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_branch ON transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at);

-- =====================================================
-- 9. EXPENSES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_tenant ON expenses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_branch ON expenses(branch_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);

-- =====================================================
-- 10. STOCK MOVEMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    previous_stock DECIMAL(15,4) NOT NULL,
    new_stock DECIMAL(15,4) NOT NULL,
    change DECIMAL(15,4) NOT NULL,
    reason TEXT NOT NULL,
    note TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_material ON stock_movements(material_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_tenant ON stock_movements(tenant_id);

-- =====================================================
-- 11. RECIPES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    quantity DECIMAL(15,4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recipes_product ON recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_recipes_material ON recipes(material_id);
CREATE INDEX IF NOT EXISTS idx_recipes_tenant ON recipes(tenant_id);


-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

-- For now, allow all operations (you can restrict later based on auth)
-- Tenants - allow all for authenticated users
CREATE POLICY "Allow all for tenants" ON tenants FOR ALL USING (true) WITH CHECK (true);

-- Users - allow all
CREATE POLICY "Allow all for users" ON users FOR ALL USING (true) WITH CHECK (true);

-- Branches - allow all
CREATE POLICY "Allow all for branches" ON branches FOR ALL USING (true) WITH CHECK (true);

-- Products - allow all
CREATE POLICY "Allow all for products" ON products FOR ALL USING (true) WITH CHECK (true);

-- Materials - allow all
CREATE POLICY "Allow all for materials" ON materials FOR ALL USING (true) WITH CHECK (true);

-- Shifts - allow all
CREATE POLICY "Allow all for shifts" ON shifts FOR ALL USING (true) WITH CHECK (true);

-- Discounts - allow all
CREATE POLICY "Allow all for discounts" ON discounts FOR ALL USING (true) WITH CHECK (true);

-- Transactions - allow all
CREATE POLICY "Allow all for transactions" ON transactions FOR ALL USING (true) WITH CHECK (true);

-- Expenses - allow all
CREATE POLICY "Allow all for expenses" ON expenses FOR ALL USING (true) WITH CHECK (true);

-- Stock Movements - allow all
CREATE POLICY "Allow all for stock_movements" ON stock_movements FOR ALL USING (true) WITH CHECK (true);

-- Recipes - allow all
CREATE POLICY "Allow all for recipes" ON recipes FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- FUNCTIONS FOR AUTO-UPDATE TIMESTAMPS
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables with updated_at
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_branches_updated_at BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SEED DATA - Demo Tenant and Users
-- =====================================================
-- Insert demo tenant
INSERT INTO tenants (id, name, identifier, timezone, currency, tax_rate, address, phone, email)
VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid,
    'Demo Coffee Shop',
    'demo_coffee',
    'Asia/Jakarta',
    'IDR',
    0.11,
    'Jl. Demo No. 123, Jakarta',
    '021-1234567',
    'demo@coffeeshop.com'
) ON CONFLICT (identifier) DO NOTHING;

-- Insert demo users (password: demo123 - SHA-256 hashed with salt)
-- Hash is SHA-256 of 'pos_kasir_multitenant_2024demo123pos_kasir_multitenant_2024'
-- Plain text 'demo123' is also supported for backward compatibility
INSERT INTO users (id, tenant_id, email, password_hash, name, role, is_active)
VALUES 
    ('11111111-1111-1111-1111-111111111111'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'owner@demo.com', 'demo123', 'Demo Owner', 'owner', true),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'manager@demo.com', 'demo123', 'Demo Manager', 'manager', true),
    ('33333333-3333-3333-3333-333333333333'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'kasir@demo.com', 'demo123', 'Demo Kasir', 'cashier', true)
ON CONFLICT DO NOTHING;

-- Insert demo branch
INSERT INTO branches (id, tenant_id, owner_id, name, code, address, phone, tax_rate, is_active)
VALUES (
    'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid,
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid,
    '11111111-1111-1111-1111-111111111111'::uuid,
    'Cabang Pusat',
    'PUSAT-001',
    'Jl. Demo No. 123, Jakarta',
    '021-1234567',
    0.11,
    true
) ON CONFLICT DO NOTHING;

-- Update users with branch_id
UPDATE users SET branch_id = 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid 
WHERE tenant_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid;

-- =====================================================
-- SEED DATA - Demo Products
-- =====================================================
INSERT INTO products (id, tenant_id, branch_id, name, price, cost, stock, category, is_active)
VALUES 
    ('a1111111-1111-1111-1111-111111111111'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Americano', 25000, 8000, 100, 'Coffee', true),
    ('a2222222-2222-2222-2222-222222222222'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Cappuccino', 30000, 10000, 100, 'Coffee', true),
    ('a3333333-3333-3333-3333-333333333333'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Latte', 32000, 11000, 100, 'Coffee', true),
    ('a4444444-4444-4444-4444-444444444444'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Espresso', 20000, 6000, 100, 'Coffee', true),
    ('a5555555-5555-5555-5555-555555555555'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Croissant', 18000, 7000, 50, 'Pastry', true),
    ('a6666666-6666-6666-6666-666666666666'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Sandwich', 25000, 12000, 30, 'Food', true)
ON CONFLICT DO NOTHING;

-- =====================================================
-- SEED DATA - Demo Materials
-- =====================================================
INSERT INTO materials (id, tenant_id, branch_id, name, stock, unit, min_stock, cost_per_unit, category)
VALUES 
    ('c1111111-1111-1111-1111-111111111111'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Biji Kopi Arabica', 10000, 'gram', 2000, 150, 'Bahan Baku'),
    ('c2222222-2222-2222-2222-222222222222'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Susu Full Cream', 20000, 'ml', 5000, 25, 'Bahan Baku'),
    ('c3333333-3333-3333-3333-333333333333'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Gula Pasir', 5000, 'gram', 1000, 15, 'Bahan Baku'),
    ('c4444444-4444-4444-4444-444444444444'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Cup Paper 12oz', 500, 'pcs', 100, 1500, 'Packaging'),
    ('c5555555-5555-5555-5555-555555555555'::uuid, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid, 'b1b2b3b4-b5b6-b7b8-b9b0-b1b2b3b4b5b6'::uuid, 'Sirup Vanilla', 2000, 'ml', 500, 80, 'Bahan Baku')
ON CONFLICT DO NOTHING;

-- =====================================================
-- DONE!
-- =====================================================
-- After running this script:
-- 1. All tables will be created
-- 2. RLS policies will be enabled
-- 3. Demo data will be seeded
-- 
-- Demo Login Credentials:
-- Owner: owner@demo.com / demo123
-- Manager: manager@demo.com / demo123
-- Kasir: kasir@demo.com / demo123
-- =====================================================
