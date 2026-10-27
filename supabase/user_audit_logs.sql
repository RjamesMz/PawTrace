-- -----------------------------------------------------------------------------
-- USER AUDIT LOGS TABLE & RLS POLICIES
-- Tracks modifications to user accounts (profile, photo, email, password, status, role)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    user_email TEXT,
    user_name TEXT,
    action TEXT NOT NULL,
    changes_summary TEXT NOT NULL,
    modified_by TEXT NOT NULL,
    modifier_role TEXT NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for fast chronological lookups per user and admin audits
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id_created_at 
ON public.user_audit_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at 
ON public.user_audit_logs(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;

-- Users can view their own audit logs
CREATE POLICY "Users can read own audit logs"
ON public.user_audit_logs
FOR SELECT
USING (auth.uid() = user_id);

-- Admins and Super Admins can view all user audit logs
CREATE POLICY "Admins can read all audit logs"
ON public.user_audit_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.user_id = auth.uid()
    AND users.role IN ('admin', 'super_admin')
  )
);

-- Authenticated users & admins can insert audit logs
CREATE POLICY "Allow authenticated audit log inserts"
ON public.user_audit_logs
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');
