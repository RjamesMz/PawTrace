-- ==============================================================================
-- PawTrace: Add Sex / Gender Columns to Users and Pets Tables
-- Database: PostgreSQL (Supabase)
-- 
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Go to "SQL Editor" in the left navigation sidebar.
-- 3. Click "New query", paste the script below, and click "Run".
-- ==============================================================================

-- 1. Add gender column to public.users if not existing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'gender'
    ) THEN
        ALTER TABLE public.users ADD COLUMN gender TEXT DEFAULT 'Male';
    END IF;
END $$;

-- 2. Add gender column to public.pets if not existing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'gender'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN gender TEXT DEFAULT 'Male';
    END IF;
END $$;
