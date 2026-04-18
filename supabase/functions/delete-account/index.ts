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

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-device-uuid",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { device_uuid } = await req.json();

    if (!device_uuid) {
      return new Response(
        JSON.stringify({ error: "device_uuid is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: user } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("device_uuid", device_uuid)
      .eq("is_deleted", false)
      .single();

    if (!user) {
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: families } = await supabaseAdmin
      .from("families")
      .select("id, line_user_id")
      .eq("user_id", user.id)
      .eq("is_active", true);

    if (families) {
      for (const family of families) {
        await pushMessage(
          family.line_user_id,
          "【みまもりタップ】連携が解除されました。ご利用ありがとうございました。"
        );
      }
    }

    await supabaseAdmin
      .from("users")
      .update({
        is_deleted: true,
        deleted_at: new Date().toISOString(),
        link_code: null,
        link_code_expires_at: null,
      })
      .eq("id", user.id);

    await supabaseAdmin
      .from("families")
      .update({ is_active: false })
      .eq("user_id", user.id);

    return new Response(
      JSON.stringify({ ok: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
