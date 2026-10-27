-- ==============================================================================
-- PawTrace: Add Last Seen Location Columns to Pets Table
-- Database: PostgreSQL (Supabase)
-- 
-- This migration allows pets to retain their last known location (lat, lon,
-- address, and timestamp) even after their GPS collar is unpaired or detached.
-- 
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Go to "SQL Editor" in the left navigation sidebar.
-- 3. Click "New query", paste the script below, and click "Run".
-- ==============================================================================

DO $$ 
BEGIN
    -- 1. Add last_seen_lat to pets table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'last_seen_lat'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN last_seen_lat DOUBLE PRECISION DEFAULT NULL;
    END IF;

    -- 2. Add last_seen_lon to pets table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'last_seen_lon'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN last_seen_lon DOUBLE PRECISION DEFAULT NULL;
    END IF;

    -- 3. Add last_seen_address to pets table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'last_seen_address'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN last_seen_address TEXT DEFAULT NULL;
    END IF;

    -- 4. Add last_seen_at to pets table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'last_seen_at'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN last_seen_at TIMESTAMPTZ DEFAULT NULL;
    END IF;
END $$;
