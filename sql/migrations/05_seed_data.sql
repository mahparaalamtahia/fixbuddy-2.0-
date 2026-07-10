-- ============================================================
-- FixBuddy Seed Data
-- File: 05_seed_data.sql
-- Run AFTER 04_functions.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- SEED: Service Categories
-- icon_name maps to Flutter Icons constant names
-- ────────────────────────────────────────────────────────────
INSERT INTO public.categories (name, icon_name, color_hex, description, is_active, sort_order) VALUES
  ('Plumber',       'plumbing',           '#1565C0', 'Water pipes, leaks, taps, and bathroom fixtures', TRUE, 1),
  ('Electrician',   'electrical_services','#F9A825', 'Wiring, switches, fans, and electrical repairs',  TRUE, 2),
  ('Carpenter',     'carpenter',          '#6D4C41', 'Furniture, doors, windows, and woodwork',         TRUE, 3),
  ('Tutor',         'school',             '#2E7D32', 'Home tuition for all subjects and levels',        TRUE, 4),
  ('Painter',       'format_paint',       '#AD1457', 'Interior and exterior painting services',         TRUE, 5),
  ('AC Technician', 'ac_unit',            '#00838F', 'AC installation, repair, and servicing',          TRUE, 6),
  ('Cleaner',       'cleaning_services',  '#558B2F', 'Home, office, and deep cleaning services',        TRUE, 7),
  ('Mason',         'home_repair_service','#4527A0', 'Brickwork, tiling, and construction repairs',     TRUE, 8),
  ('IT Support',    'computer',           '#00695C', 'Computer repair, networking, and tech support',   TRUE, 9),
  ('Locksmith',     'lock',               '#E65100', 'Lock repair, key cutting, and door security',     TRUE, 10)
ON CONFLICT (name) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- SEED: Areas (Dhaka, Bangladesh)
-- ────────────────────────────────────────────────────────────
INSERT INTO public.areas (name, city, is_active, sort_order) VALUES
  ('Uttara',       'Dhaka', TRUE, 1),
  ('Dhanmondi',    'Dhaka', TRUE, 2),
  ('Mirpur',       'Dhaka', TRUE, 3),
  ('Gulshan',      'Dhaka', TRUE, 4),
  ('Banani',       'Dhaka', TRUE, 5),
  ('Mohammadpur',  'Dhaka', TRUE, 6),
  ('Bashundhara',  'Dhaka', TRUE, 7),
  ('Motijheel',    'Dhaka', TRUE, 8),
  ('Wari',         'Dhaka', TRUE, 9),
  ('Tejgaon',      'Dhaka', TRUE, 10),
  ('Rampura',      'Dhaka', TRUE, 11),
  ('Badda',        'Dhaka', TRUE, 12),
  ('Khilgaon',     'Dhaka', TRUE, 13),
  ('Lalbagh',      'Dhaka', TRUE, 14),
  ('Shyamoli',     'Dhaka', TRUE, 15)
ON CONFLICT (name) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- SEED: App Configuration (Feature Flags)
-- ────────────────────────────────────────────────────────────
INSERT INTO public.app_config (key, value, description) VALUES
  ('feature_chat_enabled',        'true',    'Enable/disable in-app chat feature'),
  ('feature_call_enabled',        'true',    'Enable/disable direct call button'),
  ('feature_ratings_enabled',     'true',    'Enable/disable rating and review system'),
  ('maintenance_mode',            'false',   'Put app in maintenance mode for non-admins'),
  ('banner_message',              '',        'Promotional or info banner on user home screen'),
  ('min_app_version_android',     '1.0.0',   'Minimum required Android app version'),
  ('min_app_version_ios',         '1.0.0',   'Minimum required iOS app version'),
  ('max_bookings_per_day',        '3',       'Maximum bookings a user can make per day'),
  ('booking_cancellation_window', '60',      'Minutes before booking where cancellation is allowed')
ON CONFLICT (key) DO NOTHING;
