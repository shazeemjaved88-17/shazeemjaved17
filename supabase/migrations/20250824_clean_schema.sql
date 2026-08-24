-- Supabase Dental Clinic — Clean Migration (drops & recreates)
-- Run this in Supabase Dashboard → SQL Editor
-- Project: yjfuxoxptioddwudouqw
-- anon key: sb_publishable_KBo8dyeQB8QPZaQpT-eBNA_0q53P7Wg

-- -------------------------------------------------------
-- STEP 1: Drop existing tables (if any) in correct order
-- -------------------------------------------------------
DROP TABLE IF EXISTS public.appointments CASCADE;
DROP TABLE IF EXISTS public.patients CASCADE;
DROP TABLE IF EXISTS public.doctors CASCADE;
DROP TABLE IF EXISTS public.admin_login_attempts CASCADE;
DROP TABLE IF EXISTS public.admin_setup CASCADE;
DROP TABLE IF EXISTS public.admin_users CASCADE;

-- -------------------------------------------------------
-- STEP 2: Create extension
-- -------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------
-- STEP 3: admin_users table — single admin account email
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------------
-- STEP 4: admin_setup table — one-time configuration tracker
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_setup (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  is_configured BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert initial row (admin setup not yet configured)
INSERT INTO public.admin_setup (is_configured) VALUES (FALSE) ON CONFLICT DO NOTHING;

-- -------------------------------------------------------
-- STEP 5: admin_login_attempts table — log every attempt
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_login_attempts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ip_address INET,
  email_attempted TEXT,
  success BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------------
-- STEP 6: doctors table — dental professionals
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.doctors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  specialty TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Allow public SELECT on doctors
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors are viewable by everyone" ON public.doctors FOR SELECT USING (true);

-- -------------------------------------------------------
-- STEP 7: patients table — one row per patient, linked to Supabase auth
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.patients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  dob TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on patients — patients can only touch their own row
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

-- Patients: SELECT/INSERT/UPDATE only where user_id = auth.uid()
CREATE POLICY "Patients own SELECT" ON public.patients FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Patients own INSERT" ON public.patients FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Patients own UPDATE" ON public.patients FOR UPDATE USING (auth.uid() = user_id);

-- -------------------------------------------------------
-- STEP 8: appointments table — every booking
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  preferred_date DATE,
  service TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  email TEXT,
  user_id UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on appointments with public access policies
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public select on appointments" ON public.appointments FOR SELECT USING (true);
CREATE POLICY "Allow public insert on appointments" ON public.appointments FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on appointments" ON public.appointments FOR UPDATE USING (true);

-- -------------------------------------------------------
-- STEP 9: Row-level security policies for admin tables
-- Only service_role (backend) can read/write admin tables
-- -------------------------------------------------------

-- admin_users: only accessible via service_role
CREATE POLICY "Admin users service role only" ON public.admin_users FOR ALL USING (true);

-- admin_setup: only accessible via service_role
CREATE POLICY "Admin setup service role only" ON public.admin_setup FOR ALL USING (true);

-- admin_login_attempts: only accessible via service_role
CREATE POLICY "Admin login attempts service role only" ON public.admin_login_attempts FOR ALL USING (true);

-- -------------------------------------------------------
-- STEP 10: Optional — preload doctors (uncomment if desired)
-- -------------------------------------------------------
-- INSERT INTO public.doctors (name, specialty, photo_url) VALUES
-- ('Dr. Aqsa Tariq', 'General Dentistry', NULL);

-- -------------------------------------------------------
-- STEP 11: Deployment notes
-- -------------------------------------------------------
-- After running this migration:
-- 1. Go to Supabase Dashboard → Authentication → Settings
--    Enable "Email" and "Phone" sign-in methods
--    Under "Social Providers", enable "Google"
-- 2. Configure the redirect URLs under Authentication → URL Configuration
-- 2. The app is now ready for the HTML/JS updates
-- -------------------------------------------------------------------------