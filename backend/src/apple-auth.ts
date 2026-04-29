import type { Env } from "./types";

/// Verifies an Apple Sign-In identity token (a JWT) against Apple's JWKS,
/// checks audience matches your bundle ID, and returns the Apple user `sub`.
///
/// Implementation TODO when wiring this up: fetch
/// `https://appleid.apple.com/auth/keys`, find the matching `kid`, verify
/// RS256 with `crypto.subtle.verify`. Cache JWKS for a few minutes.
export async function verifyAppleIdentityToken(
  token: string,
  env: Env
): Promise<string> {
  if (!token) throw new Error("missing identityToken");

  // PLACEHOLDER: do NOT trust the token in production without verifying it.
  // For local dev, decode the unverified payload and return the `sub`.
  const payload = decodeJWTUnverified(token);
  if (!payload?.sub) throw new Error("invalid identityToken");
  if (payload.aud && payload.aud !== env.APPLE_BUNDLE_ID) {
    throw new Error("audience mismatch");
  }
  return payload.sub as string;
}

export async function verifyOptionalAppleIdentityToken(
  token: string,
  env: Env
): Promise<string | null> {
  if (!token) return null;
  return verifyAppleIdentityToken(token, env);
}

function decodeJWTUnverified(token: string): Record<string, unknown> | null {
  const [, payloadB64] = token.split(".");
  if (!payloadB64) return null;
  try {
    const json = atob(payloadB64.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(json);
  } catch {
    return null;
  }
}
