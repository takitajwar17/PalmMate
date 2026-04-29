import type { Env, InviteRecord } from "./types";
import { verifyOptionalAppleIdentityToken } from "./apple-auth";
import { createPalmMatch, fileToDataURL, isUploadedFile, json, r2ObjectToDataURL } from "./openai";

/// User A creates an invite by posting their palm photo + label. We store
/// the photo in R2 and an InviteRecord in KV, return a short token.
export async function handleCreateInvite(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const identityToken = String(form.get("identityToken") ?? "");
    const inviterUserID = await verifyOptionalAppleIdentityToken(identityToken, env);

    const photo = form.get("photo");
    const leftLabel = String(form.get("leftLabel") ?? "You");
    if (!isUploadedFile(photo)) return json({ error: "photo required" }, 400);

    const token = randomToken();
    const photoKey = `invites/${token}/left.jpg`;
    const contentType = photo.type || "image/jpeg";
    await env.PALMS.put(photoKey, await photo.arrayBuffer(), {
      httpMetadata: { contentType },
    });

    const record: InviteRecord = {
      token,
      inviterUserID,
      leftLabel,
      leftPhotoKey: photoKey,
      leftPhotoContentType: contentType,
      createdAt: Date.now(),
    };
    await env.INVITES.put(token, JSON.stringify(record), {
      // TTL: 14 days. Plenty for a friend to take their photo.
      expirationTtl: 14 * 24 * 60 * 60,
    });

    return json({
      token,
      shareURL: shareURLForToken(token),
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// Supports both same-session match readings and invite joins:
/// - leftPhoto + rightPhoto => return PalmMatchReading JSON
/// - inviteToken + photo => join an invite, run the match, persist it
export async function handleMatchReading(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const inviteToken = String(form.get("inviteToken") ?? "");
    if (inviteToken) {
      return handleJoinInviteForm(form, env, inviteToken);
    }
    return handleDirectMatchForm(form, env);
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// User A polls this to find out if their friend has joined yet.
export async function handleInviteStatus(token: string, env: Env): Promise<Response> {
  const rec = await readInvite(token, env);
  if (!rec) return json({ error: "invite not found" }, 404);
  if (rec.matchJSON) {
    return json({ state: "ready", match: parseJSON(rec.matchJSON) });
  }
  return json({ state: "waiting" });
}

async function handleDirectMatchForm(form: FormData, env: Env): Promise<Response> {
  try {
    const identityToken = String(form.get("identityToken") ?? "");
    await verifyOptionalAppleIdentityToken(identityToken, env);

    const leftPhoto = form.get("leftPhoto");
    const rightPhoto = form.get("rightPhoto");
    const leftLabel = String(form.get("leftLabel") ?? "You");
    const rightLabel = String(form.get("rightLabel") ?? "Them");
    if (!isUploadedFile(leftPhoto) || !isUploadedFile(rightPhoto)) {
      return json({ error: "leftPhoto and rightPhoto required" }, 400);
    }

    const matchJSON = await createPalmMatch(
      env,
      await fileToDataURL(leftPhoto),
      await fileToDataURL(rightPhoto),
      leftLabel,
      rightLabel
    );

    return new Response(matchJSON, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

async function handleJoinInviteForm(form: FormData, env: Env, token: string): Promise<Response> {
  try {
    const identityToken = String(form.get("identityToken") ?? "");
    const userID = await verifyOptionalAppleIdentityToken(identityToken, env);

    const photo = form.get("photo");
    const rightLabel = String(form.get("rightLabel") ?? "Them");
    if (!isUploadedFile(photo)) {
      return json({ error: "photo required" }, 400);
    }

    const rec = await readInvite(token, env);
    if (!rec) return json({ error: "invite not found" }, 404);

    const leftObject = await env.PALMS.get(rec.leftPhotoKey);
    if (!leftObject) return json({ error: "invite photo not found" }, 404);

    const rightPhotoKey = `invites/${token}/right.jpg`;
    const rightContentType = photo.type || "image/jpeg";
    const rightDataURL = await fileToDataURL(photo);
    await env.PALMS.put(rightPhotoKey, await photo.arrayBuffer(), {
      httpMetadata: { contentType: rightContentType },
    });

    const leftDataURL = await r2ObjectToDataURL(leftObject, rec.leftPhotoContentType);
    const matchJSON = await createPalmMatch(env, leftDataURL, rightDataURL, rec.leftLabel, rightLabel);

    rec.rightUserID = userID;
    rec.rightLabel = rightLabel;
    rec.rightPhotoKey = rightPhotoKey;
    rec.rightPhotoContentType = rightContentType;
    rec.matchJSON = matchJSON;

    await env.INVITES.put(token, JSON.stringify(rec));
    return json({
      token,
      shareURL: shareURLForToken(token),
      match: parseJSON(matchJSON),
      leftPhoto: {
        dataURL: leftDataURL,
      },
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
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

function shareURLForToken(token: string): string {
  return `https://palmmate.app/?invite=${token}&utm_campaign=compare_invite`;
}

function parseJSON(raw: string): unknown {
  return JSON.parse(raw);
}

function randomToken(): string {
  // Short, URL-safe, ~62 bits of entropy.
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map(b => b.toString(36).padStart(2, "0"))
    .join("");
}
