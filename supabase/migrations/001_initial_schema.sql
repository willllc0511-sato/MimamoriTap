-- みまもりタップ LINE連携 初期スキーマ
-- Supabase SQL Editorで実行してください

-- 1. users テーブル（本人＝高齢者）
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_uuid TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_tap_at TIMESTAMPTZ,
  last_mood TEXT,
  consecutive_bad_days INT NOT NULL DEFAULT 0,
  notification_state TEXT NOT NULL DEFAULT 'active',
  link_code TEXT,
  link_code_expires_at TIMESTAMPTZ,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own" ON users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "users_select_own" ON users
  FOR SELECT USING (device_uuid = current_setting('request.headers')::json->>'x-device-uuid');

CREATE POLICY "users_update_own" ON users
  FOR UPDATE USING (device_uuid = current_setting('request.headers')::json->>'x-device-uuid');

-- 2. families テーブル（家族＝LINE友だち）
CREATE TABLE families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  line_user_id TEXT NOT NULL,
  display_name TEXT,
  linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true
);

ALTER TABLE families ENABLE ROW LEVEL SECURITY;

CREATE POLICY "families_service_only" ON families
  FOR ALL USING (true) WITH CHECK (true);

-- 3. tap_logs テーブル（タップ履歴）
CREATE TABLE tap_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tapped_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  mood TEXT,
  memo TEXT
);

ALTER TABLE tap_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tap_logs_insert" ON tap_logs
  FOR INSERT WITH CHECK (true);

CREATE POLICY "tap_logs_select_own" ON tap_logs
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE device_uuid = current_setting('request.headers')::json->>'x-device-uuid')
  );

-- 4. notification_logs テーブル（通知履歴）
CREATE TABLE notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id UUID REFERENCES families(id) ON DELETE SET NULL,
  notification_type TEXT NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  line_response JSONB
);

ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_logs_service_only" ON notification_logs
  FOR ALL USING (true) WITH CHECK (true);

-- 5. インデックス
CREATE INDEX idx_users_device_uuid ON users(device_uuid);
CREATE INDEX idx_users_notification_state ON users(notification_state) WHERE is_deleted = false;
CREATE INDEX idx_families_user_id ON families(user_id) WHERE is_active = true;
CREATE INDEX idx_families_line_user_id ON families(line_user_id);
CREATE INDEX idx_tap_logs_user_id ON tap_logs(user_id);
