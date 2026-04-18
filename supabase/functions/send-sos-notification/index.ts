import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { supabaseAdmin } from "../_shared/supabase-client.ts";
import { pushMessage } from "../_shared/line-client.ts";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { device_uuid, sos_type, user_name } = await req.json();

    if (!device_uuid || !sos_type) {
      return new Response(
        JSON.stringify({ error: "device_uuid and sos_type are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ユーザー取得
    const { data: user } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("device_uuid", device_uuid)
      .eq("is_deleted", false)
      .single();

    if (!user) {
      return new Response(
        JSON.stringify({ ok: true, notified_count: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 紐づく家族を取得
    const { data: families } = await supabaseAdmin
      .from("families")
      .select("line_user_id, display_name")
      .eq("user_id", user.id)
      .eq("is_active", true);

    const activeFamilies = families ?? [];
    const displayName = user_name || "ご利用者";

    // 通知文面
    const message =
      sos_type === "longpress"
        ? `【緊急】${displayName}さんがSOSを押しました。119番に連絡しました。至急確認してください。`
        : `${displayName}さんがSOSボタンを押しました。連絡してあげてください。`;

    // 家族全員にPush送信
    for (const family of activeFamilies) {
      await pushMessage(family.line_user_id, message);
    }

    // sos_eventsに記録
    await supabaseAdmin.from("sos_events").insert({
      user_id: user.id,
      sos_type,
      notified_family_count: activeFamilies.length,
    });

    return new Response(
      JSON.stringify({ ok: true, notified_count: activeFamilies.length }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
