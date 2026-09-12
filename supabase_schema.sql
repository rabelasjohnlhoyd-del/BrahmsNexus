-- ==============================================================================
-- BRAHMS NEXUS: SUPABASE DATABASE SCHEMA & SEED DATA
-- Purpose: Static & Master Data Management (Low Write / Zero Firebase Read Cost)
-- Copy and run this script in your Supabase SQL Editor.
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. BRANCHES TABLE (Master Branch Directory)
CREATE TABLE IF NOT EXISTS public.branches (
    id TEXT PRIMARY KEY DEFAULT ('br-' || substring(uuid_generate_v4()::text, 1, 8)),
    name TEXT NOT NULL,
    municipality TEXT NOT NULL,
    daily_route_sequence INT NOT NULL DEFAULT 1,
    address TEXT DEFAULT '',
    contact_number TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 3. STAFF PROFILES TABLE (Detailed Employee Master Data)
-- Houses bulk personal fields (names, address, phone, birthdate, RFID tag)
-- so they NEVER consume Firestore storage or read operations.
CREATE TABLE IF NOT EXISTS public.staff_profiles (
    id TEXT PRIMARY KEY DEFAULT ('emp-' || substring(uuid_generate_v4()::text, 1, 8)),
    user_id TEXT, -- Corresponds to Firebase Auth UID if account exists
    first_name TEXT NOT NULL,
    middle_name TEXT DEFAULT '',
    last_name TEXT NOT NULL,
    username TEXT NOT NULL UNIQUE,
    branch_id TEXT REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE SET NULL,
    branch_name TEXT DEFAULT '',
    position TEXT NOT NULL,
    email TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    address TEXT DEFAULT '',
    age TEXT DEFAULT '',
    birthdate DATE,
    rfid_tag TEXT UNIQUE, -- Hardware RFID Card/Tag ID tapped on ESP32
    is_active BOOLEAN DEFAULT true,
    is_archived BOOLEAN DEFAULT false,
    date_added TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 4. BILAO PACKAGES TABLE (Master Package Pricing)
CREATE TABLE IF NOT EXISTS public.bilao_packages (
    id TEXT PRIMARY KEY DEFAULT ('bp-' || substring(uuid_generate_v4()::text, 1, 8)),
    size TEXT NOT NULL UNIQUE, -- 'Small', 'Medium', 'Large'
    price NUMERIC(10, 2) NOT NULL,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 5. INVENTORY MASTER ITEMS TABLE (Master Items & Standard Units)
CREATE TABLE IF NOT EXISTS public.inventory_master_items (
    id TEXT PRIMARY KEY DEFAULT ('item-' || substring(uuid_generate_v4()::text, 1, 8)),
    item_name TEXT NOT NULL UNIQUE,
    unit TEXT NOT NULL DEFAULT 'pcs',
    category TEXT NOT NULL DEFAULT 'Standard',
    default_allocation NUMERIC(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Permissive for anon key during capstone prototyping
-- ==============================================================================
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bilao_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_master_items ENABLE ROW LEVEL SECURITY;

-- Allow read/write with anon key for Brahms Nexus frontend operations
CREATE POLICY "Allow anon read branches" ON public.branches FOR SELECT USING (true);
CREATE POLICY "Allow anon modify branches" ON public.branches FOR ALL USING (true);

CREATE POLICY "Allow anon read staff_profiles" ON public.staff_profiles FOR SELECT USING (true);
CREATE POLICY "Allow anon modify staff_profiles" ON public.staff_profiles FOR ALL USING (true);

CREATE POLICY "Allow anon read bilao_packages" ON public.bilao_packages FOR SELECT USING (true);
CREATE POLICY "Allow anon modify bilao_packages" ON public.bilao_packages FOR ALL USING (true);

CREATE POLICY "Allow anon read inventory_master_items" ON public.inventory_master_items FOR SELECT USING (true);
CREATE POLICY "Allow anon modify inventory_master_items" ON public.inventory_master_items FOR ALL USING (true);

-- ==============================================================================
-- SEED DATA (Official Branches, Packages, and Staff)
-- ==============================================================================

-- Clear existing seed data if necessary (idempotent upsert)
INSERT INTO public.branches (id, name, municipality, daily_route_sequence, address)
VALUES
    ('br1', 'Brgy. Gatid', 'Sta. Cruz', 1, 'National Highway, Brgy. Gatid, Sta. Cruz, Laguna'),
    ('br2', 'Brgy. Labuin', 'Pila', 2, 'Brgy. Labuin, Pila, Laguna'),
    ('br3', 'Brgy. Sta. Clara Sur', 'Pila', 3, 'Poblacion Road, Brgy. Sta. Clara Sur, Pila, Laguna'),
    ('br4', 'Brgy. Nanhaya', 'Victoria', 4, 'Brgy. Nanhaya, Victoria, Laguna'),
    ('br5', 'Brgy. San Francisco', 'Victoria', 5, 'Brgy. San Francisco, Victoria, Laguna'),
    ('br6', 'Brgy. Dayap', 'Calauan', 6, 'Brgy. Dayap, Calauan, Laguna')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    municipality = EXCLUDED.municipality,
    daily_route_sequence = EXCLUDED.daily_route_sequence;

-- Seed Bilao Packages (from Client Interview with Boss Maverick)
INSERT INTO public.bilao_packages (id, size, price, description)
VALUES
    ('bp-small', 'Small', 750.00, 'Good for 4-6 pax with free special sauce'),
    ('bp-medium', 'Medium', 950.00, 'Good for 8-10 pax with free special sauce'),
    ('bp-large', 'Large', 1300.00, 'Good for 12-15 pax with free special sauce and extra condiments')
ON CONFLICT (id) DO UPDATE SET
    size = EXCLUDED.size,
    price = EXCLUDED.price,
    description = EXCLUDED.description;

-- Seed Master Inventory Items (The 4 core daily items + perishables)
INSERT INTO public.inventory_master_items (id, item_name, unit, category, default_allocation)
VALUES
    ('item-karne', 'Karne (Portioned Meat)', 'packs', 'Meat', 35),
    ('item-mayo', 'Mayonnaise', 'packs', 'Sauces', 40),
    ('item-toyo', 'Special Toyo Bagnet Sauce', 'bottles', 'Sauces', 7),
    ('item-styro', 'Styro Food Box', 'pcs', 'Packaging', 40),
    ('item-sibuyas', 'Sibuyas (Red Onion)', 'kg', 'Perishables', 5),
    ('item-sili', 'Sili (Green Chili)', 'kg', 'Perishables', 2)
ON CONFLICT (id) DO UPDATE SET
    item_name = EXCLUDED.item_name,
    unit = EXCLUDED.unit,
    category = EXCLUDED.category,
    default_allocation = EXCLUDED.default_allocation;

-- Seed Initial Staff Members
INSERT INTO public.staff_profiles (id, first_name, middle_name, last_name, username, branch_id, branch_name, position, phone, address, age, is_active, is_archived)
VALUES
    ('emp1', 'Juan', '', 'Dela Cruz', 'juan_cruz', 'br1', 'Brgy. Gatid, Sta. Cruz', 'Branch Cook', '0917-111-2233', 'Sta. Cruz, Laguna', '28', true, false),
    ('emp2', 'Maria', 'Clara', 'Reyes', 'maria_reyes', 'br3', 'Brgy. Sta. Clara Sur, Pila', 'Branch Cook', '0918-222-3344', 'Pila, Laguna', '25', true, false),
    ('emp3', 'Pedro', '', 'Santos', 'pedro_s', 'br2', 'Brgy. Labuin, Pila', 'Branch Cook', '0919-333-4455', 'Pila, Laguna', '31', true, false),
    ('emp4', 'Ricardo', '', 'Dalisay', 'carding_d', 'br5', 'Brgy. San Francisco, Victoria', 'Branch Cook', '0920-444-5566', 'Victoria, Laguna', '35', true, false),
    ('emp5', 'Danilo', 'P', 'Ramos', 'driver_danilo', NULL, 'N/A', 'Driver', '0921-555-6677', 'Calauan, Laguna', '34', true, false),
    ('emp6', 'Menes', '', 'Bantug', 'menes_cook', NULL, 'N/A', 'Production Area Cook', '0922-666-7788', 'Pila, Laguna', '29', true, false),
    ('emp7', 'Abby', '', 'Torres', 'abby_cutter', NULL, 'N/A', 'Production Area Meat Cutter', '0923-777-8899', 'Sta. Cruz, Laguna', '26', true, false)
ON CONFLICT (username) DO NOTHING;
