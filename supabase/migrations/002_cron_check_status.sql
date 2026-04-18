-- check-status Edge Functionを1時間ごとに実行するcronジョブ
-- Supabase SQL Editorで実行してください
-- ※ pg_cron拡張が有効であること（Supabase Proプランで利用可能、無料プランでも利用可能）

-- pg_cron拡張を有効化
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1時間ごとにcheck-status Edge Functionを呼び出す
SELECT cron.schedule(
  'check-status-hourly',
  '0 * * * *', -- 毎時0分
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/check-status',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 30日経過した削除済みアカウントを物理削除するcronジョブ（毎日深夜3時）
SELECT cron.schedule(
  'purge-deleted-accounts-daily',
  '0 3 * * *',
  $$
  DELETE FROM users
  WHERE is_deleted = true
    AND deleted_at < now() - interval '30 days';
  $$
);
