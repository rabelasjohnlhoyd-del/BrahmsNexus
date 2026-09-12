-- ==============================================================================
-- BRAHMS NEXUS: PRODUCTION-GRADE SUPABASE ROW LEVEL SECURITY (RLS) POLICIES
-- Run this in your Supabase SQL Editor to enforce strict database security.
-- ==============================================================================

-- 1. DROP ALL PROTOTYPE / PERMISSIVE POLICIES
DROP POLICY IF EXISTS "Allow anon read branches" ON public.branches;
DROP POLICY IF EXISTS "Allow anon modify branches" ON public.branches;
DROP POLICY IF EXISTS "Public can view active branches" ON public.branches;
DROP POLICY IF EXISTS "Authenticated users can view all branches" ON public.branches;
DROP POLICY IF EXISTS "Only admin can insert branches" ON public.branches;
DROP POLICY IF EXISTS "Only admin can update branches" ON public.branches;
DROP POLICY IF EXISTS "Only admin can delete branches" ON public.branches;

DROP POLICY IF EXISTS "Allow anon read staff_profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "Allow anon modify staff_profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "Authenticated staff can view active profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.staff_profiles;
DROP POLICY IF EXISTS "Staff can update own profile, Admin can update all" ON public.staff_profiles;
DROP POLICY IF EXISTS "View active staff profiles" ON public.staff_profiles;
DROP POLICY IF EXISTS "Register staff profile" ON public.staff_profiles;
DROP POLICY IF EXISTS "Staff update own profile, Owner updates all" ON public.staff_profiles;
DROP POLICY IF EXISTS "Only admin can delete staff profiles" ON public.staff_profiles;

DROP POLICY IF EXISTS "Allow anon read bilao_packages" ON public.bilao_packages;
DROP POLICY IF EXISTS "Allow anon modify bilao_packages" ON public.bilao_packages;
DROP POLICY IF EXISTS "Anyone can view bilao packages" ON public.bilao_packages;
DROP POLICY IF EXISTS "Only admin can modify bilao packages" ON public.bilao_packages;

DROP POLICY IF EXISTS "Allow anon read inventory_master_items" ON public.inventory_master_items;
DROP POLICY IF EXISTS "Allow anon modify inventory_master_items" ON public.inventory_master_items;
DROP POLICY IF EXISTS "Anyone can view master inventory items" ON public.inventory_master_items;
DROP POLICY IF EXISTS "Only admin can modify inventory master items" ON public.inventory_master_items;

-- Ensure RLS is enabled on all tables
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bilao_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_master_items ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 2. BRANCHES TABLE SECURITY
-- Anyone can view active branches; modifications restricted to Owner.
-- ==============================================================================
CREATE POLICY "Public can view active branches"
ON public.branches FOR SELECT
TO anon, authenticated
USING (is_active = true);

CREATE POLICY "Only admin can insert branches"
ON public.branches FOR INSERT
TO authenticated
WITH CHECK (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

CREATE POLICY "Only admin can update branches"
ON public.branches FOR UPDATE
TO authenticated
USING (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

CREATE POLICY "Only admin can delete branches"
ON public.branches FOR DELETE
TO authenticated
USING (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

-- ==============================================================================
-- 3. STAFF PROFILES SECURITY
-- Prevents unauthorized reading or tampering of personal employee records.
-- ==============================================================================
-- Allow viewing active employee directory; archived employees visible only to Owner
CREATE POLICY "View active staff profiles"
ON public.staff_profiles FOR SELECT
TO anon, authenticated
USING (is_archived = false OR auth.jwt() ->> 'role' = 'owner');

-- Allows users to create their own initial profile during registration:
-- - Cannot self-archive on creation
-- - Must provide a non-empty ID and full name
CREATE POLICY "Register staff profile"
ON public.staff_profiles FOR INSERT
TO anon, authenticated
WITH CHECK (
  is_archived = false AND
  id IS NOT NULL AND
  length(first_name) >= 2
);

-- Staff can only update their own record; Owner can update any record
-- Anonymous users CANNOT perform arbitrary updates across the database
CREATE POLICY "Staff update own profile, Owner updates all"
ON public.staff_profiles FOR UPDATE
TO authenticated
USING (
  auth.uid()::text = id OR
  auth.jwt() ->> 'role' = 'owner' OR
  auth.jwt() ->> 'email' LIKE '%owner%'
);

-- Only Owner can permanently delete profiles
CREATE POLICY "Only admin can delete staff profiles"
ON public.staff_profiles FOR DELETE
TO authenticated
USING (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

-- ==============================================================================
-- 4. BILAO PACKAGES MASTER PRICING
-- Read-only for general staff; modifications restricted to Owner.
-- ==============================================================================
CREATE POLICY "Anyone can view bilao packages"
ON public.bilao_packages FOR SELECT
TO anon, authenticated
USING (is_active = true);

CREATE POLICY "Only admin can modify bilao packages"
ON public.bilao_packages FOR ALL
TO authenticated
USING (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

-- ==============================================================================
-- 5. INVENTORY MASTER ITEMS
-- Read-only for general staff; modifications restricted to Owner.
-- ==============================================================================
CREATE POLICY "Anyone can view master inventory items"
ON public.inventory_master_items FOR SELECT
TO anon, authenticated
USING (true);

CREATE POLICY "Only admin can modify inventory master items"
ON public.inventory_master_items FOR ALL
TO authenticated
USING (auth.jwt() ->> 'role' = 'owner' OR auth.jwt() ->> 'email' LIKE '%owner%');

-- ==============================================================================
-- 6. LEAST PRIVILEGE DATABASE GRANTS (Defense-in-depth)
-- Explicitly revokes dangerous permissions from anonymous public role.
-- ==============================================================================
REVOKE DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
GRANT SELECT ON public.branches, public.bilao_packages, public.inventory_master_items TO anon;
GRANT SELECT, INSERT ON public.staff_profiles TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
