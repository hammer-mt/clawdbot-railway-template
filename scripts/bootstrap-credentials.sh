#!/bin/sh
# Bootstrap credentials from Railway environment variables on container startup.
# This allows API keys and OAuth tokens to be stored as Railway secrets
# and reconstituted into the config files that tools (gws, gcloud) expect.

set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"

# --- Google Workspace CLI (gws) credentials ---
# Requires: GWS_CLIENT_ID, GWS_CLIENT_SECRET, GWS_REFRESH_TOKEN
if [ -n "$GWS_CLIENT_ID" ] && [ -n "$GWS_CLIENT_SECRET" ] && [ -n "$GWS_REFRESH_TOKEN" ]; then
  GWS_CREDS_DIR="$STATE_DIR/gws"
  mkdir -p "$GWS_CREDS_DIR"

  # Write credentials.json for gws
  cat > "$GWS_CREDS_DIR/credentials.json" <<GWSEOF
{
  "client_id": "$GWS_CLIENT_ID",
  "client_secret": "$GWS_CLIENT_SECRET",
  "refresh_token": "$GWS_REFRESH_TOKEN",
  "type": "authorized_user"
}
GWSEOF
  chmod 600 "$GWS_CREDS_DIR/credentials.json"

  # Write client_secret.json if GWS_PROJECT_ID is set
  if [ -n "$GWS_PROJECT_ID" ]; then
    cat > "$GWS_CREDS_DIR/client_secret.json" <<CSEOF
{
  "installed": {
    "client_id": "$GWS_CLIENT_ID",
    "client_secret": "$GWS_CLIENT_SECRET",
    "project_id": "$GWS_PROJECT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token"
  }
}
CSEOF
    chmod 600 "$GWS_CREDS_DIR/client_secret.json"
  fi

  # Point gws to our credentials
  export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="$GWS_CREDS_DIR/credentials.json"
  export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="$GWS_CREDS_DIR/client_secret.json"
  echo "[bootstrap] GWS credentials written to $GWS_CREDS_DIR"
fi

# --- Google Cloud (gcloud) application default credentials ---
# Reuse the same OAuth token for GCS access
if [ -n "$GWS_CLIENT_ID" ] && [ -n "$GWS_CLIENT_SECRET" ] && [ -n "$GWS_REFRESH_TOKEN" ]; then
  GCLOUD_DIR="/root/.config/gcloud"
  mkdir -p "$GCLOUD_DIR"

  cat > "$GCLOUD_DIR/application_default_credentials.json" <<ADCEOF
{
  "client_id": "$GWS_CLIENT_ID",
  "client_secret": "$GWS_CLIENT_SECRET",
  "refresh_token": "$GWS_REFRESH_TOKEN",
  "type": "authorized_user"
}
ADCEOF
  chmod 600 "$GCLOUD_DIR/application_default_credentials.json"

  # Set the GCP project if provided
  if [ -n "$GCP_PROJECT_ID" ]; then
    gcloud config set project "$GCP_PROJECT_ID" --quiet 2>/dev/null || true
  fi
  echo "[bootstrap] gcloud ADC written to $GCLOUD_DIR"
fi

# --- Cloudflare R2 credentials (for rclone) ---
# Requires: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
if [ -n "$R2_ACCESS_KEY_ID" ] && [ -n "$R2_SECRET_ACCESS_KEY" ]; then
  RCLONE_DIR="/root/.config/rclone"
  mkdir -p "$RCLONE_DIR"

  R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  cat > "$RCLONE_DIR/rclone.conf" <<R2EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = $R2_ACCESS_KEY_ID
secret_access_key = $R2_SECRET_ACCESS_KEY
endpoint = $R2_ENDPOINT
acl = private
R2EOF
  chmod 600 "$RCLONE_DIR/rclone.conf"
  echo "[bootstrap] R2 rclone config written to $RCLONE_DIR"
fi

echo "[bootstrap] Credential bootstrap complete"
