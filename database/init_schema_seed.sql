-- FitTrack PostgreSQL schema + minimal seed data
-- This file is executed by startup.sh on container start.
-- It is designed to be idempotent and safe to run multiple times.

BEGIN;

-- Enable helpful extensions (pgcrypto for gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ===============
-- Core tables
-- ===============

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL UNIQUE,
    refresh_token TEXT UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_access_token ON sessions(access_token);

CREATE TABLE IF NOT EXISTS workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workout_date DATE NOT NULL,
    workout_type TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes >= 0),
    calories_burned INTEGER NOT NULL DEFAULT 0 CHECK (calories_burned >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workouts_user_date ON workouts(user_id, workout_date);

CREATE TABLE IF NOT EXISTS daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,
    steps INTEGER NOT NULL DEFAULT 0 CHECK (steps >= 0),
    calories INTEGER NOT NULL DEFAULT 0 CHECK (calories >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, metric_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_metrics_user_date ON daily_metrics(user_id, metric_date);

CREATE TABLE IF NOT EXISTS goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL, -- e.g. 'steps', 'calories', 'workouts_per_week'
    target_value INTEGER NOT NULL CHECK (target_value >= 0),
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goals_user_active ON goals(user_id, is_active);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL, -- e.g. 'goal_achieved', 'reminder'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- =========================
-- Minimal seed/demo data
-- =========================

-- Demo user
INSERT INTO users (id, email, password_hash, full_name)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'demo@fittrack.app',
    'demo_password_hash_change_me',
    'Demo User'
)
ON CONFLICT (email) DO NOTHING;

-- Demo workouts (a couple, for UI previews)
INSERT INTO workouts (id, user_id, workout_date, workout_type, duration_minutes, calories_burned, notes)
VALUES
    (
        '22222222-2222-2222-2222-222222222221',
        '11111111-1111-1111-1111-111111111111',
        CURRENT_DATE - INTERVAL '1 day',
        'Running',
        30,
        320,
        'Easy run around the park'
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111',
        CURRENT_DATE,
        'Strength Training',
        45,
        280,
        'Upper body focus'
    )
ON CONFLICT (id) DO NOTHING;

-- Demo daily metrics (steps + calories)
INSERT INTO daily_metrics (id, user_id, metric_date, steps, calories)
VALUES
    (
        '33333333-3333-3333-3333-333333333331',
        '11111111-1111-1111-1111-111111111111',
        CURRENT_DATE - INTERVAL '1 day',
        8420,
        2150
    ),
    (
        '33333333-3333-3333-3333-333333333332',
        '11111111-1111-1111-1111-111111111111',
        CURRENT_DATE,
        10450,
        2350
    )
ON CONFLICT (user_id, metric_date) DO UPDATE
SET steps = EXCLUDED.steps,
    calories = EXCLUDED.calories;

-- Demo goals
INSERT INTO goals (id, user_id, goal_type, target_value, start_date, end_date, is_active)
VALUES
    (
        '44444444-4444-4444-4444-444444444441',
        '11111111-1111-1111-1111-111111111111',
        'steps',
        10000,
        CURRENT_DATE - INTERVAL '7 days',
        NULL,
        TRUE
    ),
    (
        '44444444-4444-4444-4444-444444444442',
        '11111111-1111-1111-1111-111111111111',
        'calories',
        2200,
        CURRENT_DATE - INTERVAL '7 days',
        NULL,
        TRUE
    )
ON CONFLICT (id) DO NOTHING;

-- Demo notifications (optional previews)
INSERT INTO notifications (id, user_id, notification_type, title, body, is_read)
VALUES
    (
        '55555555-5555-5555-5555-555555555551',
        '11111111-1111-1111-1111-111111111111',
        'welcome',
        'Welcome to FitTrack',
        'Your demo account is ready. Explore dashboard stats, workouts, and goals.',
        FALSE
    ),
    (
        '55555555-5555-5555-5555-555555555552',
        '11111111-1111-1111-1111-111111111111',
        'goal_progress',
        'Steps goal in progress',
        'You are close to your 10,000-step goal for today.',
        FALSE
    )
ON CONFLICT (id) DO NOTHING;

COMMIT;
