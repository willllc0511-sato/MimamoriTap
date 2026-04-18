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

/** LINE署名を検証 */
export async function verifySignature(
  body: string,
  signature: string
): Promise<boolean> {
  const secret = getChannelSecret();
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const expected = btoa(String.fromCharCode(...new Uint8Array(sig)));
  return expected === signature;
}

/** Reply APIでメッセージ返信 */
export async function replyMessage(
  replyToken: string,
  text: string
): Promise<void> {
  await fetch(`${LINE_API_BASE}/message/reply`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getChannelAccessToken()}`,
    },
    body: JSON.stringify({
      replyToken,
      messages: [{ type: "text", text }],
    }),
  });
}

/** Push APIでメッセージ送信 */
export async function pushMessage(
  to: string,
  text: string
): Promise<Response> {
  return await fetch(`${LINE_API_BASE}/message/push`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${getChannelAccessToken()}`,
    },
    body: JSON.stringify({
      to,
      messages: [{ type: "text", text }],
    }),
  });
}
