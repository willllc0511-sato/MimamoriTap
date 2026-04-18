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

function getChannelSecret(): string {
  const secret = Deno.env.get("LINE_CHANNEL_SECRET");
  if (!secret) throw new Error("LINE_CHANNEL_SECRET is not set");
  return secret;
}

async function verifySignature(body: string, signature: string): Promise<boolean> {
  const secret = getChannelSecret();
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expected = btoa(String.fromCharCode(...new Uint8Array(sig)));
  return expected === signature;
}

async function replyMessage(replyToken: string, text: string): Promise<void> {
  await fetch(`${LINE_API_BASE}/message/reply`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getChannelAccessToken()}`,
    },
    body: JSON.stringify({ replyToken, messages: [{ type: "text", text }] }),
  });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const body = await req.text();
  const signature = req.headers.get("x-line-signature") || "";

  const valid = await verifySignature(body, signature);
  if (!valid) {
    return new Response("Invalid signature", { status: 403 });
  }

  const { events } = JSON.parse(body);

  for (const event of events) {
    const lineUserId = event.source?.userId;
    if (!lineUserId) continue;

    switch (event.type) {
      case "follow":
        await replyMessage(
          event.replyToken,
          "みまもりタップです。\n\nアプリに表示された連携コード（8桁）を送ってください。"
        );
        break;

      case "unfollow":
        await supabaseAdmin
          .from("families")
          .update({ is_active: false })
          .eq("line_user_id", lineUserId);
        break;

      case "message":
        if (event.message?.type === "text") {
          const text = event.message.text.trim();

          if (text === "通知再開") {
            const { data: families } = await supabaseAdmin
              .from("families")
              .select("user_id")
              .eq("line_user_id", lineUserId)
              .eq("is_active", true);

            if (!families || families.length === 0) {
              await replyMessage(event.replyToken, "連携中のアカウントが見つかりません。アプリから連携コードを発行してください。");
            } else {
              const userIds = families.map((f: any) => f.user_id);
              await supabaseAdmin
                .from("users")
                .update({ notification_state: "active" })
                .in("id", userIds);
              await replyMessage(event.replyToken, "通知を再開しました。安否通知をお届けします。");
            }
            break;
          }

          const codePattern = /^[A-HJ-NP-Z2-9]{8}$/;
          if (codePattern.test(text.toUpperCase())) {
            const code = text.toUpperCase();
            const { data: user } = await supabaseAdmin
              .from("users")
              .select("id, link_code, link_code_expires_at")
              .eq("link_code", code)
              .eq("is_deleted", false)
              .single();

            if (!user) {
              await replyMessage(event.replyToken, "連携コードが見つかりません。コードをご確認ください。");
              break;
            }

            if (user.link_code_expires_at && new Date(user.link_code_expires_at) < new Date()) {
              await replyMessage(event.replyToken, "連携コードの有効期限が切れています。アプリで新しいコードを発行してください。");
              break;
            }

            const { data: existing } = await supabaseAdmin
              .from("families")
              .select("id")
              .eq("user_id", user.id)
              .eq("line_user_id", lineUserId)
              .single();

            if (existing) {
              await supabaseAdmin.from("families").update({ is_active: true }).eq("id", existing.id);
              await replyMessage(event.replyToken, "連携を再開しました！安否通知をお届けします。");
            } else {
              await supabaseAdmin.from("families").insert({ user_id: user.id, line_user_id: lineUserId });
              await replyMessage(event.replyToken, "連携が完了しました！\n\nタップが一定時間ない場合や、体調不良が続いた場合にお知らせします。\n\n通知を一時停止中に再開したい場合は「通知再開」と送信してください。");
            }

            await supabaseAdmin
              .from("users")
              .update({ link_code: null, link_code_expires_at: null })
              .eq("id", user.id);
            break;
          }

          await replyMessage(event.replyToken, "連携コード（8桁）を送信するか、「通知再開」と送信してください。");
        }
        break;
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
