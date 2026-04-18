import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const LINE_API_BASE = "https://api.line.me/v2/bot";

function getChannelAccessToken(): string {
  const token = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN");
  if (!token) throw new Error("LINE_CHANNEL_ACCESS_TOKEN is not set");
  return token;
}

async function pushMessage(to: string, text: string): Promise<Response> {
  return await fetch(`${LINE_API_BASE}/message/push`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getChannelAccessToken()}`,
    },
    body: JSON.stringify({ to, messages: [{ type: "text", text }] }),
  });
}

serve(async (_req) => {
  try {
    const now = new Date();

    const { data: users, error } = await supabaseAdmin
      .from("users")
      .select("id, last_tap_at, consecutive_bad_days, notification_state")
      .eq("is_deleted", false);

    if (error) throw error;
    if (!users) return jsonResponse({ ok: true, processed: 0 });

    let notified = 0;

    for (const user of users) {
      if (!user.last_tap_at) continue;

      const lastTap = new Date(user.last_tap_at);
      const hoursSince = (now.getTime() - lastTap.getTime()) / (1000 * 60 * 60);

      if (user.notification_state === "active" && hoursSince >= 24) {
        await notifyFamilies(user.id, "24h", "【みまもりタップ】24時間反応がありません。お時間のある時にご様子を確認してみてください。");
        await updateState(user.id, "alerted_24h");
        notified++;
      }

      if (user.notification_state === "alerted_24h" && hoursSince >= 72) {
        await notifyFamilies(user.id, "72h", "【みまもりタップ】72時間反応がありません。直接のご確認をおすすめします。");
        await updateState(user.id, "alerted_72h");
        notified++;
      }

      if (user.notification_state === "alerted_72h" && hoursSince >= 96) {
        await updateState(user.id, "optimized");
      }

      if (user.consecutive_bad_days >= 3) {
        await notifyFamilies(user.id, "bad_3days", "【みまもりタップ】3日連続で「調子悪い」と記録されています。お声がけをおすすめします。");
        await supabaseAdmin.from("users").update({ consecutive_bad_days: 0 }).eq("id", user.id);
        notified++;
      }
    }

    return jsonResponse({ ok: true, processed: users.length, notified });
  } catch (err) {
    return jsonResponse({ error: err.message }, 500);
  }
});

async function notifyFamilies(userId: string, type: string, message: string) {
  const { data: families } = await supabaseAdmin
    .from("families")
    .select("id, line_user_id")
    .eq("user_id", userId)
    .eq("is_active", true);

  if (!families) return;

  for (const family of families) {
    const res = await pushMessage(family.line_user_id, message);
    const lineResponse = await res.json().catch(() => null);
    await supabaseAdmin.from("notification_logs").insert({
      user_id: userId,
      family_id: family.id,
      notification_type: type,
      line_response: lineResponse,
    });
  }
}

async function updateState(userId: string, state: string) {
  await supabaseAdmin.from("users").update({ notification_state: state }).eq("id", userId);
}

function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
