-- ==============================================================================
-- PawTrace: Analytics & Search Performance Optimization Indexes
-- Database: PostgreSQL (Supabase)
-- 
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard/project/lxkwugncakjbnffwphuq
-- 2. Go to "SQL Editor" in the left navigation sidebar.
-- 3. Click "New query", paste the script below, and click "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. LOST REPORTS (Heavy Analytics, Joined Lookups & Dashboard Range Filters)
-- ------------------------------------------------------------------------------

-- Barangay-scoped queries (used across all Admin dashboard metrics & filters)
CREATE INDEX IF NOT EXISTS idx_lost_reports_barangay 
ON public.lost_reports(barangay);

-- Date-based sorting & range filtering (used for trend charts, this month / year)
CREATE INDEX IF NOT EXISTS idx_lost_reports_reported_at 
ON public.lost_reports(reported_at DESC);

-- Composite index: barangay + reported_at (optimized for dashboard date range queries)
CREATE INDEX IF NOT EXISTS idx_lost_reports_barangay_reported_at 
ON public.lost_reports(barangay, reported_at DESC);

-- Report status filter ('active' vs 'archived' / 'resolved')
CREATE INDEX IF NOT EXISTS idx_lost_reports_status 
ON public.lost_reports(status);

-- Foreign key lookup to pets (crucial for select('*, pets(*)') join speed)
CREATE INDEX IF NOT EXISTS idx_lost_reports_pet_id 
ON public.lost_reports(pet_id);

-- Foreign key lookup to owner/users
CREATE INDEX IF NOT EXISTS idx_lost_reports_owner_id 
ON public.lost_reports(owner_id);


-- ------------------------------------------------------------------------------
-- 2. PETS TABLE (Registry, Demographics, & Species / Status Filtering)
-- ------------------------------------------------------------------------------

-- Barangay filter for admin registry and analytics
CREATE INDEX IF NOT EXISTS idx_pets_barangay 
ON public.pets(barangay);

-- Status filter ('active', 'lost', 'archived')
CREATE INDEX IF NOT EXISTS idx_pets_status 
ON public.pets(status);

-- Composite index: barangay + status (used for active lost reports & active pet counts)
CREATE INDEX IF NOT EXISTS idx_pets_barangay_status 
ON public.pets(barangay, status);

-- Species breakdown (cat, dog, other) for demographics donut chart
CREATE INDEX IF NOT EXISTS idx_pets_species 
ON public.pets(species);

-- Owner foreign key join
CREATE INDEX IF NOT EXISTS idx_pets_owner_id 
ON public.pets(owner_id);

-- Partial index for active GPS collars (Collar Pairing KPI card & map dialog)
CREATE INDEX IF NOT EXISTS idx_pets_gps_id 
ON public.pets(gps_id) 
WHERE gps_id IS NOT NULL;


-- ------------------------------------------------------------------------------
-- 3. USERS TABLE (User Growth Trend & Role Scoping)
-- ------------------------------------------------------------------------------

-- User registration timeline (used for User Registration Growth line chart)
CREATE INDEX IF NOT EXISTS idx_users_created_at 
ON public.users(created_at DESC);

-- Barangay-scoped user registration growth
CREATE INDEX IF NOT EXISTS idx_users_barangay_created_at 
ON public.users(barangay, created_at DESC);

-- Role filtering (admin, owner, super_admin)
CREATE INDEX IF NOT EXISTS idx_users_role 
ON public.users(role);


-- ------------------------------------------------------------------------------
-- 4. PET AUDIT LOGS (Pet History, Audit Dialogs & Excel Export)
-- ------------------------------------------------------------------------------

-- Fast lookup of audit history per pet sorted chronologically
CREATE INDEX IF NOT EXISTS idx_pet_audit_logs_pet_id_timestamp 
ON public.pet_audit_logs(pet_id, timestamp DESC);


-- ------------------------------------------------------------------------------
-- 5. ALERTS & NOTIFICATIONS (Real-time Broadcasts & Unread Alert Polling)
-- ------------------------------------------------------------------------------

-- User notification feed lookup
CREATE INDEX IF NOT EXISTS idx_alerts_user_id 
ON public.alerts(user_id);

-- Notification feed sorting
CREATE INDEX IF NOT EXISTS idx_alerts_created_at 
ON public.alerts(created_at DESC);


-- ------------------------------------------------------------------------------
-- 6. (OPTIONAL RECOMMENDED) Add `found_at` / `updated_at` to lost_reports
-- This enables native timestamping for exact recovery duration analytics.
-- ------------------------------------------------------------------------------

DO $$ 
BEGIN
    -- Add found_at column if not existing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_reports' AND column_name = 'found_at'
    ) THEN
        ALTER TABLE public.lost_reports ADD COLUMN found_at TIMESTAMPTZ DEFAULT NULL;
    END IF;

    -- Add updated_at column if not existing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_reports' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.lost_reports ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;
