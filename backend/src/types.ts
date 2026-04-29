/// Cloudflare Worker bindings declared in `wrangler.toml`.
export interface Env {
  PALMS: R2Bucket;
  INVITES: KVNamespace;
  OPENAI_API_KEY: string;
  APPLE_BUNDLE_ID: string;
}

export interface InviteRecord {
  token: string;
  inviterUserID: string | null;
  leftLabel: string;
  leftPhotoKey: string;     // R2 object key for inviter's palm
  leftPhotoContentType: string;
  createdAt: number;
  rightUserID?: string | null;
  rightLabel?: string;
  rightPhotoKey?: string;
  rightPhotoContentType?: string;
  matchJSON?: string;       // populated once both palms have arrived
}
