-- SOS発信イベント記録テーブル
CREATE TABLE sos_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sos_type TEXT NOT NULL,
  notified_family_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE sos_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sos_events_service_only" ON sos_events
  FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX idx_sos_events_user_id ON sos_events(user_id);
