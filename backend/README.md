# PalmMate Backend

Tiny Cloudflare Worker that does two jobs:

1. **OpenAI proxy.** The iOS app sends a palm photo, and when available an
   Apple Sign-In identity token. The Worker calls
   OpenAI with the developer key (server-side, never shipped to clients),
   and returns the structured reading or diagram image.
2. **Pair-invite registry.** Powers the viral "Compare with a friend" flow.
   User A creates an invite (their palm photo is uploaded, indexed by an
   `invite` token). User B opens `palmmate.app/?invite=<token>` on their
   phone, the app deep-links into the Compare flow, B uploads their palm,
   and the Worker stitches the pair, calls OpenAI for the match reading,
   and returns it to both clients.

## Layout

```
backend/
├── src/
│   ├── worker.ts          # entry point + router
│   ├── openai.ts          # palm + match analysis (server-side OpenAI key)
│   ├── prompts.ts         # bundled prompts mirrored from the iOS resources
│   ├── apple-auth.ts      # Apple Sign-In identity-token verification
│   ├── pair.ts            # invite create / join / poll handlers
│   └── types.ts
├── wrangler.toml          # Cloudflare config (R2 for photos, KV for invites)
└── package.json
```

## Endpoints

```
POST /v1/readings/solo
  Body:    multipart/form-data { photo: jpg, identityToken?: string }
  Returns: PalmReading JSON

POST /v1/readings/match
  Body A:  multipart/form-data { leftPhoto: jpg, rightPhoto: jpg,
                                 leftLabel?, rightLabel?, identityToken?: string }
  Returns: PalmMatchReading JSON

  Body B:  multipart/form-data { inviteToken: string, photo: jpg,
                                 rightLabel?, identityToken?: string }
  Returns: { token, shareURL, match, leftPhoto }

POST /v1/images/diagram
  Body:    application/json { prompt: string, size?: string, identityToken?: string }
  Returns: { b64JSON?: string, url?: string }

POST /v1/invites
  Body:    multipart/form-data { photo: jpg, leftLabel: string,
                                 identityToken?: string }
  Returns: { token: string, shareURL: string }

GET  /v1/invites/:token/status
  Returns: { state: "waiting" | "ready", match?: PalmMatchReading }
```

## Deploy (rough)

```
npm install
# Configure wrangler.toml with your R2 bucket + KV namespace IDs
# Set secrets:
wrangler secret put OPENAI_API_KEY
wrangler secret put APPLE_BUNDLE_ID  # com.palmmate.app
wrangler deploy
```

## GitHub Actions deploy

The repository includes `.github/workflows/deploy-backend.yml`. Every push
to `main` installs the backend dependencies, type-checks the Worker, runs
`wrangler deploy --dry-run`, then deploys to Cloudflare.

Set these in GitHub before relying on the workflow:

- Repository variable: `CLOUDFLARE_ACCOUNT_ID`
- Repository secret: `CLOUDFLARE_API_TOKEN`

Worker runtime secrets such as `OPENAI_API_KEY` and `APPLE_BUNDLE_ID` are
stored in Cloudflare via `wrangler secret put`; they are not committed and
do not need to be present in GitHub Actions for a normal deploy.

## Status

The Worker is wired for backend-first solo readings, diagram generation,
same-session match readings, and invite joins. Apple token verification is
still a development placeholder and identity tokens are optional so guest
mode can use the backend. Before scale, replace that with real Apple JWKS
verification plus App Attest or rate limiting.
