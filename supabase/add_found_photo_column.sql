-- ==============================================================================
-- Migration: Add found_photo_url & found_at to lost_reports and pets
-- ==============================================================================
-- This supports saving the live photo captured by pet owners when marking
-- their lost pet as found, allowing admins to inspect and verify the found picture.

DO $$ 
BEGIN
    -- 1. Add found_photo_url to lost_reports
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_reports' AND column_name = 'found_photo_url'
    ) THEN
        ALTER TABLE public.lost_reports ADD COLUMN found_photo_url TEXT DEFAULT NULL;
    END IF;

    -- 2. Add found_at to lost_reports if not already present
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_reports' AND column_name = 'found_at'
    ) THEN
        ALTER TABLE public.lost_reports ADD COLUMN found_at TIMESTAMPTZ DEFAULT NULL;
    END IF;

    -- 3. Add found_photo_url to pets
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pets' AND column_name = 'found_photo_url'
    ) THEN
        ALTER TABLE public.pets ADD COLUMN found_photo_url TEXT DEFAULT NULL;
    END IF;
END $$;
