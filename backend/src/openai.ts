import type { Env } from "./types";
import { verifyOptionalAppleIdentityToken } from "./apple-auth";
import { palmCompareSkill, palmReadingSkill } from "./prompts";

type ChatContent =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string; detail: "high" | "low" | "auto" } };

/// Solo palm reading. The iOS app POSTs a photo; this Worker calls OpenAI
/// server-side and returns the structured JSON the app already decodes.
export async function handleSoloReading(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const identityToken = String(form.get("identityToken") ?? "");
    await verifyOptionalAppleIdentityToken(identityToken, env);

    const photo = form.get("photo");
    if (!isUploadedFile(photo)) {
      return json({ error: "photo required" }, 400);
    }

    const dataURL = await fileToDataURL(photo);
    const content = await createPalmReading(env, dataURL);

    return new Response(content, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// Diagram generation proxy. Keeps `gpt-image-1` calls and the OpenAI key off
/// the device while returning the same image payload shape the app expects.
export async function handleDiagramImage(request: Request, env: Env): Promise<Response> {
  try {
    const payload = (await request.json()) as { prompt?: unknown; size?: unknown; identityToken?: unknown };
    await verifyOptionalAppleIdentityToken(String(payload.identityToken ?? ""), env);

    const prompt = String(payload.prompt ?? "").trim();
    if (!prompt) return json({ error: "prompt required" }, 400);

    const size = typeof payload.size === "string" && payload.size ? payload.size : "1024x1024";
    const resp = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: openAIHeaders(env),
      body: JSON.stringify({
        model: "gpt-image-1",
        prompt,
        size,
        n: 1,
      }),
    });

    const data = await readOpenAIJSON(resp);
    const first = Array.isArray(data.data) ? data.data[0] : undefined;
    const b64JSON = typeof first?.b64_json === "string" ? first.b64_json : undefined;
    const url = typeof first?.url === "string" ? first.url : undefined;
    if (!b64JSON && !url) return json({ error: "empty image response" }, 502);

    return json({ b64JSON, url });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

export async function createPalmReading(env: Env, palmDataURL: string): Promise<string> {
  return postChat(env, palmReadingSkill, [
    {
      type: "text",
      text: "Read this palm. Return ONLY a JSON object matching the schema in your instructions. Be specific about what you literally see in the photo.",
    },
    { type: "image_url", image_url: { url: palmDataURL, detail: "high" } },
  ]);
}

export async function createPalmMatch(
  env: Env,
  leftDataURL: string,
  rightDataURL: string,
  leftLabel: string,
  rightLabel: string
): Promise<string> {
  return postChat(env, palmCompareSkill, [
    {
      type: "text",
      text:
        `Compare these two palms.\nleftLabel: "${leftLabel}"\nrightLabel: "${rightLabel}"\n` +
        `The first image is "${leftLabel}". The second image is "${rightLabel}". ` +
        "Return ONLY the JSON object matching the schema in your instructions.",
    },
    { type: "image_url", image_url: { url: leftDataURL, detail: "high" } },
    { type: "image_url", image_url: { url: rightDataURL, detail: "high" } },
  ]);
}

export async function fileToDataURL(file: File): Promise<string> {
  const buf = await file.arrayBuffer();
  return arrayBufferToDataURL(buf, file.type || "image/jpeg");
}

export async function r2ObjectToDataURL(object: R2ObjectBody, contentType = "image/jpeg"): Promise<string> {
  return arrayBufferToDataURL(await object.arrayBuffer(), contentType);
}

export function isUploadedFile(value: unknown): value is File {
  return (
    typeof value === "object" &&
    value !== null &&
    "arrayBuffer" in value &&
    typeof value.arrayBuffer === "function" &&
    "type" in value
  );
}

export function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function arrayBufferToDataURL(buf: ArrayBuffer, contentType: string): string {
  return `data:${contentType};base64,${bufferToBase64(buf)}`;
}

async function postChat(env: Env, systemPrompt: string, content: ChatContent[]): Promise<string> {
  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: openAIHeaders(env),
    body: JSON.stringify({
      model: "gpt-4o",
      temperature: 0.85,
      max_tokens: 1600,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content },
      ],
    }),
  });

  const data = await readOpenAIJSON(resp);
  const contentText = data.choices?.[0]?.message?.content;
  if (typeof contentText !== "string" || !contentText) {
    throw new Error("empty OpenAI response");
  }
  return contentText;
}

function openAIHeaders(env: Env): HeadersInit {
  return {
    Authorization: `Bearer ${env.OPENAI_API_KEY}`,
    "Content-Type": "application/json",
  };
}

async function readOpenAIJSON(resp: Response): Promise<any> {
  const raw = await resp.text();
  let data: any;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { error: raw };
  }
  if (!resp.ok) {
    const message =
      typeof data?.error?.message === "string"
        ? data.error.message
        : typeof data?.error === "string"
          ? data.error
          : `OpenAI HTTP ${resp.status}`;
    throw new Error(message);
  }
  return data;
}

function bufferToBase64(buf: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}
