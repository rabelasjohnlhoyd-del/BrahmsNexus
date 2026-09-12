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

-- Seed Bilao Packages (Official pricing & cook commissions from Client)
INSERT INTO public.bilao_packages (id, size, price, description)
VALUES
    ('bp-small', 'Small', 650.00, 'Good for 10 Pax (1.25 kg) | Cook Commission: ₱62'),
    ('bp-medium', 'Medium', 900.00, 'Good for 15 Pax (1.75 kg) | Cook Commission: ₱87'),
    ('bp-large', 'Large', 1300.00, 'Good for 20 Pax (2.5 kg) | Cook Commission: ₱125')
ON CONFLICT (id) DO UPDATE SET
    size = EXCLUDED.size,
    price = EXCLUDED.price,
    description = EXCLUDED.description;

-- Seed Master Inventory Items (The 3 Karne portion types + consumables)
INSERT INTO public.inventory_master_items (id, item_name, unit, category, default_allocation)
VALUES
    ('item-karne-reg', 'Karne Regular (250g - ₱130)', 'pcs', 'Meat', 20),
    ('item-karne-med', 'Karne Medium (300g - ₱160)', 'pcs', 'Meat', 10),
    ('item-karne-b1t1', 'Karne B1T1 (400g - ₱210)', 'pcs', 'Meat', 10),
    ('item-mayo', 'Mayonnaise', 'packs', 'Sauces', 40),
    ('item-toyo', 'Special Toyo Bagnet Sauce', 'bottles', 'Sauces', 7),
    ('item-styro', 'Styro Food Container Box', 'pcs', 'Packaging', 40),
    ('item-sibuyas', 'Sibuyas (Red Onion)', 'kg', 'Perishables', 5),
    ('item-sili', 'Sili (Green Chili)', 'kg', 'Perishables', 2)
ON CONFLICT (id) DO UPDATE SET
    item_name = EXCLUDED.item_name,
    unit = EXCLUDED.unit,
    category = EXCLUDED.category,
    default_allocation = EXCLUDED.default_allocation;

-- Seed Official Staff Members (Actual Client Personnel)
INSERT INTO public.staff_profiles (id, first_name, middle_name, last_name, username, branch_id, branch_name, position, phone, address, is_active, is_archived)
VALUES
    ('emp1', 'Leany', 'Hernandez', 'Malla', 'leany_malla', 'br6', 'Brgy. Dayap, Calauan', 'Branch Cook', '09917063234', 'San Francisco, Victoria, Laguna', true, false),
    ('emp2', 'Jobelle', 'T', 'Fuentes', 'jobelle_fuentes', 'br2', 'Brgy. Labuin, Pila', 'Branch Cook', '09260715146', 'Linga, Pila, Laguna', true, false),
    ('emp3', 'Virgenita', '', 'Espiritu', 'virgenita_espiritu', 'br4', 'Brgy. Nanhaya, Victoria', 'Branch Cook', '09853652758', 'San Roque, Victoria, Laguna', true, false),
    ('emp4', 'Jovelle', 'P', 'Camila', 'jovelle_camila', 'br1', 'Brgy. Gatid, Sta. Cruz', 'Branch Cook', '09655818582', 'Gatid, Sta. Cruz, Laguna', true, false),
    ('emp5', 'Patricia Mharie', 'M', 'Espiritu', 'patricia_espiritu', 'br3', 'Brgy. Sta. Clara Sur, Pila', 'Branch Cook', '09152319790', 'San Francisco, Victoria, Laguna', true, false),
    ('emp6', 'Alma', 'D', 'Agonos', 'alma_agonos', 'br5', 'Brgy. San Francisco, Victoria', 'Branch Cook', '09949178538', 'San Roque, Victoria, Laguna', true, false),
    ('emp7', 'Menes', '', 'Bantug', 'menes_cook', NULL, 'N/A', 'Production Cook', 'Pending Info', 'Production Area', true, false),
    ('emp8', 'Abby', '', 'Torres', 'abby_cutter', NULL, 'N/A', 'Production Meat Cutter', 'Pending Info', 'Production Area', true, false),
    ('emp9', 'Danilo', '', 'Ramos', 'danilo_driver', NULL, 'N/A', 'Driver', 'Pending Info', 'Logistics / Delivery', true, false),
    ('emp10', 'Extra Cook 1', '', '(Floating)', 'floating_cook_1', NULL, 'Floating / Any Branch', 'Floating Cook', 'Pending Info', 'Laguna', true, false),
    ('emp11', 'Extra Cook 2', '', '(Floating)', 'floating_cook_2', NULL, 'Floating / Any Branch', 'Floating Cook', 'Pending Info', 'Laguna', true, false),
    ('emp12', 'Extra Cook 3', '', '(Floating)', 'floating_cook_3', NULL, 'Floating / Any Branch', 'Floating Cook', 'Pending Info', 'Laguna', true, false)
ON CONFLICT (username) DO NOTHING;
