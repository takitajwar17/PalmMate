import type { Env, InviteRecord } from "./types";
import { verifyAppleIdentityToken } from "./apple-auth";
import { json } from "./openai";

/// User A creates an invite by posting their palm photo + label. We store
/// the photo in R2 and an InviteRecord in KV, return a short token.
export async function handleCreateInvite(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const identityToken = String(form.get("identityToken") ?? "");
    const inviterUserID = await verifyAppleIdentityToken(identityToken, env);

    const photo = form.get("photo");
    const leftLabel = String(form.get("leftLabel") ?? "You");
    if (!(photo instanceof File)) return json({ error: "photo required" }, 400);

    const token = randomToken();
    const photoKey = `invites/${token}/left.jpg`;
    await env.PALMS.put(photoKey, await photo.arrayBuffer(), {
      httpMetadata: { contentType: photo.type || "image/jpeg" },
    });

    const record: InviteRecord = {
      token,
      inviterUserID,
      leftLabel,
      leftPhotoKey: photoKey,
      createdAt: Date.now(),
    };
    await env.INVITES.put(token, JSON.stringify(record), {
      // TTL: 14 days. Plenty for a friend to take their photo.
      expirationTtl: 14 * 24 * 60 * 60,
    });

    return json({
      token,
      shareURL: `https://palmmate.app/?invite=${token}&utm_campaign=compare_invite`,
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// User B (the invitee) posts their palm against an invite token. If both
/// palms are present, we run the match reading server-side and persist it.
export async function handleJoinInvite(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const identityToken = String(form.get("identityToken") ?? "");
    const userID = await verifyAppleIdentityToken(identityToken, env);

    const token = String(form.get("inviteToken") ?? "");
    const photo = form.get("photo");
    const rightLabel = String(form.get("rightLabel") ?? "Them");
    if (!token || !(photo instanceof File)) {
      return json({ error: "inviteToken and photo required" }, 400);
    }

    const rec = await readInvite(token, env);
    if (!rec) return json({ error: "invite not found" }, 404);

    const photoKey = `invites/${token}/right.jpg`;
    await env.PALMS.put(photoKey, await photo.arrayBuffer(), {
      httpMetadata: { contentType: photo.type || "image/jpeg" },
    });

    rec.rightUserID = userID;
    rec.rightLabel = rightLabel;
    rec.rightPhotoKey = photoKey;

    // TODO: fetch both photos from R2, build the OpenAI request with both
    // image_urls, hit /chat/completions with PalmCompareSkill as the system
    // prompt, store rec.matchJSON.
    rec.matchJSON = JSON.stringify({ pending: true });

    await env.INVITES.put(token, JSON.stringify(rec));
    return new Response(rec.matchJSON, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// User A polls this to find out if their friend has joined yet.
export async function handleInviteStatus(token: string, env: Env): Promise<Response> {
  const rec = await readInvite(token, env);
  if (!rec) return json({ error: "invite not found" }, 404);
  if (rec.matchJSON) {
    return json({ state: "ready", match: JSON.parse(rec.matchJSON) });
  }
  return json({ state: "waiting" });
}

async function readInvite(token: string, env: Env): Promise<InviteRecord | null> {
  const raw = await env.INVITES.get(token);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as InviteRecord;
  } catch {
    return null;
  }
}

function randomToken(): string {
  // Short, URL-safe, ~62 bits of entropy.
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map(b => b.toString(36).padStart(2, "0"))
    .join("");
}
