-- ==============================================================================
-- PawTrace: Resident-Scoped Lost Reports (Owner Barangay, 7-Day Indexes & RLS)
-- Database: PostgreSQL (Supabase)
-- ==============================================================================

-- 1. Add backward-compatible `owner_barangay` column to `public.lost_reports`
ALTER TABLE public.lost_reports
ADD COLUMN IF NOT EXISTS owner_barangay TEXT;

-- 2. Backfill `owner_barangay` and repair `barangay` for all existing records
--    (Previously, reverse-geocoded street addresses were saved into `lost_reports.barangay`
--     when reporting a lost pet, causing barangay queries to miss those reports.)
UPDATE public.lost_reports lr
SET
  owner_barangay = COALESCE(NULLIF(u.barangay, ''), lr.owner_barangay),
  barangay = COALESCE(NULLIF(u.barangay, ''), lr.barangay)
FROM public.users u
WHERE lr.owner_id = u.user_id;

UPDATE public.lost_reports lr
SET
  owner_barangay = COALESCE(NULLIF(lr.owner_barangay, ''), p.barangay),
  barangay = COALESCE(NULLIF(p.barangay, ''), lr.barangay)
FROM public.pets p
WHERE lr.pet_id = p.pet_id
  AND (lr.owner_barangay IS NULL OR lr.owner_barangay = '');

-- 3. Trigger function to keep `owner_barangay` synced with the owner's registered barangay
CREATE OR REPLACE FUNCTION public.sync_lost_report_owner_barangay()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.owner_id IS NOT NULL AND (NEW.owner_barangay IS NULL OR NEW.owner_barangay = '') THEN
    SELECT u.barangay
      INTO NEW.owner_barangay
      FROM public.users u
     WHERE u.user_id = NEW.owner_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_lost_report_owner_barangay ON public.lost_reports;
CREATE TRIGGER trg_sync_lost_report_owner_barangay
BEFORE INSERT OR UPDATE OF owner_id ON public.lost_reports
FOR EACH ROW
EXECUTE FUNCTION public.sync_lost_report_owner_barangay();

-- 4. Indexes for 7-day Recent Activity & owner-barangay lookups
CREATE INDEX IF NOT EXISTS idx_lost_reports_owner_id_reported_at
ON public.lost_reports(owner_id, reported_at DESC);

CREATE INDEX IF NOT EXISTS idx_lost_reports_owner_barangay_reported_at
ON public.lost_reports(owner_barangay, reported_at DESC);

CREATE INDEX IF NOT EXISTS idx_users_barangay_user_id
ON public.users(barangay, user_id);

-- 5. Row-Level Security (RLS) helper and policy to enforce strict barangay isolation
--    Ensures a Barangay Admin (`role = 'admin'`) can only read lost reports belonging
--    to residents of their own registered barangay, even if querying the API directly.
CREATE OR REPLACE FUNCTION public.can_access_lost_report(report_owner_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users viewer
    LEFT JOIN public.users owner_user ON owner_user.user_id = report_owner_id
    WHERE viewer.user_id = auth.uid()
      AND (
        -- Super admins and regular community users retain standard visibility
        viewer.role IN ('super_admin', 'user')
        -- Report owner can always read their own report
        OR viewer.user_id = report_owner_id
        -- Barangay admins can ONLY see reports from residents of their own barangay
        OR (
          viewer.role = 'admin'
          AND viewer.barangay IS NOT NULL
          AND owner_user.barangay IS NOT NULL
          AND lower(trim(viewer.barangay)) = lower(trim(owner_user.barangay))
        )
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_access_lost_report(UUID) TO authenticated;

ALTER TABLE public.lost_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Barangay admins only see reports from their own residents"
ON public.lost_reports;

CREATE POLICY "Barangay admins only see reports from their own residents"
ON public.lost_reports
FOR SELECT
TO authenticated
USING (public.can_access_lost_report(owner_id));

