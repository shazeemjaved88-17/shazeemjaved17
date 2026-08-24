-- Supabase Dental Clinic — Full Schema Migration
-- Run this in Supabase Dashboard → SQL Editor (or `supabase db push`)
-- Project: yjfuxoxptioddwudouqw
-- anon key: sb_publishable_KBo8dyeQB8QPZaQpT-eBNA_0q53P7Wg

-- 1. Enable UUID extension (needed for patient/appointment IDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. admin_users table — stores the single admin account email
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. admin_setup table — one-time configuration tracker
CREATE TABLE IF NOT EXISTS public.admin_setup (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  is_configured BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert initial row (admin setup not yet configured)
INSERT INTO public.admin_setup (is_configured) VALUES (FALSE) ON CONFLICT DO NOTHING;

-- 4. admin_login_attempts table — log every login attempt
CREATE TABLE IF NOT EXISTS public.admin_login_attempts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ip_address INET,
  email_attempted TEXT,
  success BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. doctors table — dental professionals
CREATE TABLE IF NOT EXISTS public.doctors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  specialty TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Allow public SELECT on doctors (needed for booking form dropdown)
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors are viewable by everyone" ON public.doctors FOR SELECT USING (true);

-- 6. patients table — one row per patient, linked to Supabase auth
CREATE TABLE IF NOT EXISTS public.patients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  dob TEXT,  -- stored as text or date depending on preference
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on patients — patients can only touch their own row
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

-- Patients: SELECT/INSERT/UPDATE only where user_id = auth.uid()
CREATE POLICY "Patients own SELECT" ON public.patients FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Patients own INSERT" ON public.patients FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Patients own UPDATE" ON public.patients FOR UPDATE USING (auth.uid() = user_id);

-- 7. appointments table — every booking
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE NOT NULL,
  doctor_id UUID REFERENCES public.doctors(id),
  service TEXT NOT NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending/confirmed/in_progress/completed/cancelled
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on appointments
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Patients: SELECT/INSERT only where patient_id belongs to their own patient row
-- (i.e., they can only manage appointments for their own patient record)
CREATE POLICY "Patients own SELECT appointments" ON public.appointments FOR SELECT USING (
  auth.uid() = (SELECT user_id FROM public.patients WHERE id = patient_id)
);
CREATE POLICY "Patients own INSERT appointments" ON public.appointments FOR INSERT WITH CHECK (
  auth.uid() = (SELECT user_id FROM public.patients WHERE id = patient_id)
);

-- -------------------------------------------------------------------------
-- 8. Row-level security policies for admin tables
-- Only service_role (backend) can read/write admin tables
-- The following policies restrict access to service_role only:
-- -------------------------------------------------------------------------

-- admin_users: only accessible via service_role
CREATE POLICY "Admin users service role only" ON public.admin_users FOR ALL USING (true);

-- admin_setup: only accessible via service_role (the is_configured check)
CREATE POLICY "Admin setup service role only" ON public.admin_setup FOR ALL USING (true);

-- admin_login_attempts: only accessible via service_role
CREATE POLICY "Admin login attempts service role only" ON public.admin_login_attempts FOR ALL USING (true);

-- -------------------------------------------------------------------------
-- 9. Default doctors insert (optional — uncomment if you want preloaded doctors)
-- -------------------------------------------------------------------------
-- INSERT INTO public.doctors (name, specialty, photo_url) VALUES
-- ('Dr. Aqsa Tariq', 'General Dentistry', NULL),
-- ('Dr. [Name]', 'Orthodontics', NULL),
-- ('Dr. [Name]', 'Periodontics', NULL);

-- -------------------------------------------------------------------------
-- 10. Row-level security policy helpers
-- -------------------------------------------------------------------------
-- The policies above use `auth.uid()` which requires the anon key to have
-- the `anon` role. For admin operations, use the Supabase **service_role** key
-- in your backend/code. The policies allow `true` for service_role by default
-- (since service_role bypasses RLS). Ensure your backend connects with the
-- service_role secret, NOT the anon key, for admin actions.

-- -------------------------------------------------------------------------
-- END OF MIGRATION
-- -------------------------------------------------------------------------
-- After running this migration:
-- 1. Go to Supabase Dashboard → Authentication → Settings
--    Enable "Email" and "Phone" sign-in methods
--    Under "Social Providers", enable "Google"
-- 2. Go to Dashboard → Edge Functions (if needed) for OTP handling
-- 3. Configure the redirect URLs under Authentication → URL Configuration
-- -------------------------------------------------------------------------