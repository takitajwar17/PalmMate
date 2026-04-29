import type { Env } from "./types";
import { verifyAppleIdentityToken } from "./apple-auth";

/// Solo palm reading. The iOS app POSTs the photo + Apple identity token;
/// this Worker calls OpenAI server-side and returns the structured JSON.
export async function handleSoloReading(request: Request, env: Env): Promise<Response> {
  try {
    const form = await request.formData();
    const identityToken = String(form.get("identityToken") ?? "");
    await verifyAppleIdentityToken(identityToken, env);

    const photo = form.get("photo");
    if (!(photo instanceof File)) {
      return json({ error: "photo required" }, 400);
    }

    const dataURL = await fileToDataURL(photo);
    const systemPrompt = await loadPalmReadingSkill();

    const body = {
      model: "gpt-4o",
      temperature: 0.85,
      max_tokens: 1600,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            { type: "text", text: "Read this palm. Return ONLY a JSON object matching the schema in your instructions." },
            { type: "image_url", image_url: { url: dataURL, detail: "high" } },
          ],
        },
      ],
    };

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const txt = await resp.text();
      return json({ error: txt || `HTTP ${resp.status}` }, resp.status);
    }

    const data = (await resp.json()) as {
      choices: { message: { content: string } }[];
    };
    const content = data.choices?.[0]?.message?.content;
    if (!content) return json({ error: "empty response" }, 502);

    // Pass through the raw JSON the model produced. iOS decodes it into
    // PalmReading.
    return new Response(content, {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return json({ error: (err as Error).message }, 400);
  }
}

/// TODO: bundle the same PalmReadingSkill.md as a build-time string. For now
/// keep a tight inline fallback. The iOS bundle remains the source of truth
/// during dev.
async function loadPalmReadingSkill(): Promise<string> {
  return "You are a master palmist. Output ONLY a JSON object matching the schema documented in PalmReadingSkill.md.";
}

async function fileToDataURL(file: File): Promise<string> {
  const buf = await file.arrayBuffer();
  const b64 = bufferToBase64(buf);
  return `data:${file.type || "image/jpeg"};base64,${b64}`;
}

function bufferToBase64(buf: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
