# PalmMate — AI Palm Reading iOS App

Take a photo of a palm. Get back an editorial palm-reading guide rendered
in the style of an old occult atlas — bone paper, engraved hand illustration,
vermillion ink. Tap **Compare Palms** to read yours against a friend's.
Powered by GPT-4o vision and `gpt-image-1`.

App Store branding:

- **Name:** PalmMate: Palm Reading
- **Subtitle:** Free Palm Scanner
- **Slogan:** Scan your palm. Compare your story.

```
SwiftUI · iOS 16+ · Apple Sign-In · GPT-4o + gpt-image-1 · RevenueCat-ready
```

### Design direction

**Editorial occult-atlas.** Warm bone paper (`#F2EBDC`), deep ink, single
vermillion accent (`#B83121`). No purple gradients. Custom fonts bundled in
`Resources/Fonts/`: **Cormorant Garamond** (display), **EB Garamond**
(body), **JetBrains Mono** (eyebrow labels). Custom SVG palm engraving
drawn from scratch in SwiftUI Canvas — used everywhere instead of SF Symbols.

## What it does

1. **Sign in with Apple or guest mode.** Guest users get one free reading
   before being prompted to sign in.
2. **Read a palm** — camera or library → GPT-4o (with the bundled
   `PalmReadingSkill.md` system prompt) → structured JSON →
   `gpt-image-1` draws the contour artwork → editorial in-app guide.
3. **Half-paywalled preview.** Free users see the photo, the contour
   diagram, the At-a-Glance headline, and the factual line descriptors.
   The major-line cards, palm features, "What This Means For You", and
   "Your Path" are blurred behind an Unlock CTA.
4. **Compare Palms (Pro feature).** Two-photo flow → `PalmCompareSkill.md`
   system prompt → `PalmMatchReading` JSON with a 0–100 score, label
   ("Twin Flames", "Slow Burn", …), six dynamics cards, and advice.
5. **Viral share.** Both readings export to a branded poster card. Free
   users share a teaser card (no locked content revealed) with a
   "Read yours" CTA URL. Subscribers get the full editorial poster.
6. **Compare invite deep link** (`palmmate://compare?invite=<token>`)
   routes recipients into the Compare flow when they install the app.
   The `/backend` Cloudflare Worker handles real pair-stitching.

## Monetization (hybrid)

- **Solo readings: free**, with the editorial gate above.
- **Single-reading unlock:** $1.99, one-time. For users who don't want to
  subscribe and just want this one reading.
- **Pro subscription:** $2.99/mo or $19.99/yr. Unlocks the full reading
  every time + unlimited Compare Palms.

RevenueCat is stubbed in `PurchaseManager.swift` — wire the SDK + your API
key in `Config.swift` to ship.

## Architecture

```
.
├── bootstrap.sh                         # one-shot setup (xcodegen + xcconfig)
├── Makefile                             # `make bootstrap | open | build | clean`
├── PalmMate/                            # SwiftUI app
│   ├── PalmMate/
│   │   ├── PalmMateApp.swift
│   │   ├── Info.plist                   # PalmMate display name, camera/photo perms,
│   │   │                                # OPENAI_API_KEY, BACKEND_BASE_URL,
│   │   │                                # palmmate:// scheme
│   │   ├── PalmMate.entitlements        # Apple Sign-In capability
│   │   ├── Config.xcconfig.example      # template for keys + backend URL
│   │   ├── Models/
│   │   │   ├── PalmReading.swift
│   │   │   └── PalmMatchReading.swift
│   │   ├── Services/
│   │   │   ├── Config.swift             # API keys, product IDs, share URLs
│   │   │   ├── OpenAIService.swift      # solo + match analysis + image gen
│   │   │   ├── SkillLoader.swift        # loads bundled .md system prompts
│   │   │   ├── AuthManager.swift        # Apple Sign-In
│   │   │   ├── PurchaseManager.swift    # subscription + per-reading unlock
│   │   │   ├── DeepLinkRouter.swift     # palmmate:// / palmmate.app routing
│   │   │   ├── ReadingStore.swift       # FileManager persistence for saved readings
│   │   │   └── ImageExporter.swift      # full / teaser / match poster renderer
│   │   ├── Views/
│   │   │   ├── SignInView.swift
│   │   │   ├── ContentView.swift        # main + Compare CTA
│   │   │   ├── CameraPicker.swift
│   │   │   ├── PaywallView.swift        # sub + one-off
│   │   │   ├── SettingsView.swift
│   │   │   ├── ResultView.swift         # editorial guide + LockedSection
│   │   │   ├── CompareView.swift        # two-photo capture
│   │   │   ├── MatchResultView.swift    # match guide
│   │   │   ├── LockedSection.swift      # blur + Unlock CTA wrapper
│   │   │   ├── ShareSheet.swift         # UIActivityViewController bridge
│   │   │   ├── EditorialPaper.swift     # design tokens (P.*), fonts (F.*), atoms
│   │   │   ├── AnimatedHand.swift       # floating palm engraving animation
│   │   │   ├── OnboardingView.swift     # 3-page onboarding (folio style)
│   │   │   ├── HistoryView.swift        # "Your Scrolls" — saved readings list
│   │   │   └── MysticalBackground.swift # night background (analyzing screen only)
│   │   └── Resources/
│   │       ├── PalmReadingSkill.md      # solo reading system prompt
│   │       ├── PalmCompareSkill.md      # match reading system prompt
│   │       └── Fonts/                   # Cormorant Garamond, EB Garamond, JetBrains Mono
│   └── project.yml                      # XcodeGen
├── backend/                             # Cloudflare Worker
│   ├── src/                             # OpenAI proxy + pair invite endpoints
│   ├── wrangler.toml
│   ├── tsconfig.json
│   ├── package.json
│   ├── .dev.vars.example                # template for local Worker secrets
│   └── README.md
└── README.md
```

## Setup

### iOS app — one command

```bash
git clone https://github.com/oh-ashen-one/full-palm-reading-ios-app.git
cd full-palm-reading-ios-app
make open
```

`make open` (or `./bootstrap.sh --open`) does everything:

1. Installs `xcodegen` via Homebrew if missing.
2. Copies `Config.xcconfig.example` → `Config.xcconfig` (gitignored).
3. Generates `PalmMate.xcodeproj` from `project.yml`.
4. Opens the project in Xcode.

Then, in Xcode:

1. Open `PalmMate/PalmMate/Config.xcconfig` and paste your
   `OPENAI_API_KEY` (from <https://platform.openai.com/api-keys>).
2. Select the `PalmMate` target → Signing & Capabilities → set your
   **Team**. The `Sign In with Apple` capability is already declared.
3. Plug in a physical iPhone and hit Run. Apple Sign-In will not work
   in the simulator — you need real hardware.

#### Other useful targets

```bash
make help         # list everything
make build        # headless simulator build, no signing (CI sanity check)
make clean        # remove the generated .xcodeproj
make backend-dev  # run the Cloudflare Worker locally
```

### Backend (optional for MVP)

Until the backend is deployed, the iOS app does same-session compare on
the user's device (works fine — just no invite-link virality). Deploy the
Worker when you want pair-stitching:

```bash
cd backend
npm install
cp .dev.vars.example .dev.vars   # paste your OPENAI_API_KEY for local dev
npm run dev                      # local Worker on http://localhost:8787

# When ready to ship:
wrangler secret put OPENAI_API_KEY
wrangler secret put APPLE_BUNDLE_ID  # com.palmmate.app
wrangler deploy
```

See `backend/README.md` for endpoints + status. The Apple-token verifier
in `apple-auth.ts` is a placeholder — wire real JWKS verification before
production.

## The skill files

The app's intelligence lives in two markdown files that ship in the iOS
bundle and are loaded as system prompts at request time:

- **`PalmReadingSkill.md`** — solo reading. Strict JSON schema (At a Glance,
  Palm Lines, five Major-Line cards, Palm Features, What This Means For
  You, Your Path), tone rules, and reference knowledge from Western
  (Cheiro, Benham), Indian (Hast Samudrika Shastra), and Chinese
  palmistry: hand shapes, all major + minor lines, mounts, marks, finger
  + thumb signs.
- **`PalmCompareSkill.md`** — two-palm compatibility reading. Score (0–100)
  + label, dynamics across love / communication / energy / direction /
  shared strengths / friction. Same tradition-grounded reference set.

To improve readings, edit those files.

## Going to production

1. **Move the OpenAI call behind the backend.** Shipping
   `OPENAI_API_KEY` in the binary lets anyone extract and abuse it.
   Stand up the `/backend` Worker (`OPENAI_API_KEY` as a Cloudflare
   secret, never in the app), point `BACKEND_BASE_URL` at it, and
   refactor `OpenAIService` to call the Worker instead of OpenAI
   directly.
2. **Wire RevenueCat.** Add the SPM dep
   (`https://github.com/RevenueCat/purchases-ios-spm`), set
   `Config.revenueCatAPIKey`, configure in `PalmMateApp.init()`, and
   replace the stub bodies in `PurchaseManager`. Create products in App
   Store Connect: `palmmate.sub.monthly` ($2.99),
   `palmmate.sub.yearly` ($19.99), `palmmate.unlock.single` ($1.99).
   Single entitlement: `pro`.
3. **Universal Links.** For best deep-link UX, register
   `palmmate.app/.well-known/apple-app-site-association` and add the
   Associated Domains entitlement. Custom scheme works as a fallback.

## Marketing playbook (out of scope for app code, in scope for launch)

These are GTM tactics from the brief. They're not iOS features — but
they're how this app crushes:

- **TikTok slideshow stories.** "Ways the palm reading changed someone's
  life" — 5–10 stylized slides per story, generated with `gpt-image-1`
  (the same model the app already uses). A small Node/Python script can
  batch these from a list of testimonial prompts.
- **Pinned-comment seeding.** Pin a real founder or creator comment such
  as "PalmMate gives the first scan free; compare is the viral hook."
  Disclose paid creator work where required.
- **Link in bio.** `palmmate.app` → App Store. The same URL the share
  cards already point at.
- **UGC at $10/clip via SideShift.** Ten creators, ten 30-second clips,
  pick the best two by save-rate, put paid spend behind them.

The iOS app is intentionally a wrapper — the moats are the editorial
output style, the invite-deep-link virality, and the GTM playbook above.

## Privacy

- Photos go to OpenAI at read time. Not stored by the app.
- Apple Sign-In stores only the user identifier and (if opted in) name.
- No analytics SDK is included.
