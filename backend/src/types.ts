/// Cloudflare Worker bindings declared in `wrangler.toml`.
export interface Env {
  PALMS: R2Bucket;
  INVITES: KVNamespace;
  OPENAI_API_KEY: string;
  APPLE_BUNDLE_ID: string;
}

export interface InviteRecord {
  token: string;
  inviterUserID: string;
  leftLabel: string;
  leftPhotoKey: string;     // R2 object key for inviter's palm
  createdAt: number;
  rightUserID?: string;
  rightLabel?: string;
  rightPhotoKey?: string;
  matchJSON?: string;       // populated once both palms have arrived
}
