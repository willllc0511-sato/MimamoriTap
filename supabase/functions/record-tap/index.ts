import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

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
    const { device_uuid, mood, memo } = await req.json();

    if (!device_uuid) {
      return new Response(
        JSON.stringify({ error: "device_uuid is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let { data: user } = await supabaseAdmin
      .from("users")
      .select("id, consecutive_bad_days, notification_state")
      .eq("device_uuid", device_uuid)
      .eq("is_deleted", false)
      .single();

    if (!user) {
      const { data: newUser, error: insertError } = await supabaseAdmin
        .from("users")
        .insert({ device_uuid })
        .select("id, consecutive_bad_days, notification_state")
        .single();

      if (insertError) {
        return new Response(
          JSON.stringify({ error: "Failed to create user" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      user = newUser;
    }

    await supabaseAdmin.from("tap_logs").insert({
      user_id: user.id,
      mood,
      memo,
    });

    const newBadDays = mood === "bad" ? user.consecutive_bad_days + 1 : 0;

    await supabaseAdmin
      .from("users")
      .update({
        last_tap_at: new Date().toISOString(),
        last_mood: mood,
        consecutive_bad_days: newBadDays,
        notification_state: "active",
      })
      .eq("id", user.id);

    return new Response(
      JSON.stringify({ ok: true, user_id: user.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
