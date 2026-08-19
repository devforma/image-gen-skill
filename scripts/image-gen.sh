#!/usr/bin/env bash
set -euo pipefail

API_URL="https://cf.api.fan/v1/images/generations"
MODEL="gpt-image-2"
PROMPT=""
SIZE="1k"
QUALITY="medium"
COUNT=1
OUTPUT_PREFIX="image"
API_KEY="${PACKY_IMAGE_API_KEY:-}"

usage() {
  cat <<'EOF'
Usage:
  bash image-gen.sh --prompt "description" [options]

Options:
  -p, --prompt TEXT     Prompt (required)
  -s, --size SIZE       1k | 2k | 4k | WIDTHxHEIGHT (default: 1k)
  -q, --quality LEVEL   high | medium | low (default: medium)
  -n, --count N         Number of images (default: 1)
  -o, --output NAME     Output path prefix (default: image)
  -k, --api-key KEY     API key; prefer PACKY_IMAGE_API_KEY
  -h, --help            Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 ]] || die "Missing value for $1"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

resolve_size() {
  case "$1" in
    1k|1K) printf '1536x1024' ;;
    2k|2K) printf '2048x1152' ;;
    4k|4K) printf '3840x2160' ;;
    *)
      [[ "$1" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] ||
        die "Size must be 1k, 2k, 4k, or WIDTHxHEIGHT"
      printf '%s' "$1"
      ;;
  esac
}

decode_base64() {
  if base64 --decode </dev/null >/dev/null 2>&1; then
    base64 --decode
  elif base64 -d </dev/null >/dev/null 2>&1; then
    base64 -d
  else
    base64 -D
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--prompt)
      require_value "$@"
      PROMPT="$2"
      shift 2
      ;;
    -s|--size)
      require_value "$@"
      SIZE="$2"
      shift 2
      ;;
    -q|--quality)
      require_value "$@"
      QUALITY="$2"
      shift 2
      ;;
    -n|--count)
      require_value "$@"
      COUNT="$2"
      shift 2
      ;;
    -o|--output)
      require_value "$@"
      OUTPUT_PREFIX="$2"
      shift 2
      ;;
    -k|--api-key)
      require_value "$@"
      API_KEY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$PROMPT" ]] || die "Prompt is required"
[[ -n "$API_KEY" ]] || die "Set PACKY_IMAGE_API_KEY or pass --api-key"
case "$QUALITY" in
  high|medium|low) ;;
  *) die "Quality must be high, medium, or low" ;;
esac
[[ "$COUNT" =~ ^[1-9][0-9]*$ ]] || die "Count must be a positive integer"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v base64 >/dev/null 2>&1 || die "base64 is required"

SIZE="$(resolve_size "$SIZE")"
OUTPUT_PREFIX="${OUTPUT_PREFIX%.png}"
REQUEST_BODY=$(printf '{"model":"%s","prompt":"%s","size":"%s","quality":"%s","output_format":"png","n":%s}' \
  "$MODEL" "$(json_escape "$PROMPT")" "$SIZE" "$QUALITY" "$COUNT")

TEMP_ROOT="${TMPDIR:-/tmp}"
RESPONSE_FILE="$(mktemp "$TEMP_ROOT/image-gen-response.XXXXXX")"
IMAGE_DATA_FILE="$(mktemp "$TEMP_ROOT/image-gen-data.XXXXXX")"
cleanup() {
  rm -f "$RESPONSE_FILE" "$IMAGE_DATA_FILE"
}
trap cleanup EXIT

curl --silent --show-error --fail --location "$API_URL" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $API_KEY" \
  --data "$REQUEST_BODY" \
  --output "$RESPONSE_FILE" ||
  die "Image generation request failed"

tr -d '\r\n' <"$RESPONSE_FILE" |
  sed 's/"b64_json"[[:space:]]*:[[:space:]]*"/\
/g' |
  awk 'NR > 1 { sub(/".*/, ""); print }' >"$IMAGE_DATA_FILE"

[[ -s "$IMAGE_DATA_FILE" ]] ||
  die "The response did not contain b64_json image data"

INDEX=0
while IFS= read -r IMAGE_DATA; do
  INDEX=$((INDEX + 1))
  if [[ "$COUNT" -eq 1 ]]; then
    OUTPUT_FILE="${OUTPUT_PREFIX}.png"
  else
    OUTPUT_FILE="${OUTPUT_PREFIX}-${INDEX}.png"
  fi

  mkdir -p "$(dirname "$OUTPUT_FILE")"
  TEMP_OUTPUT="${OUTPUT_FILE}.tmp"
  if ! printf '%s' "$IMAGE_DATA" | decode_base64 >"$TEMP_OUTPUT"; then
    rm -f "$TEMP_OUTPUT"
    die "Could not decode image $INDEX"
  fi
  mv -f "$TEMP_OUTPUT" "$OUTPUT_FILE"
  printf 'Saved: %s\n' "$OUTPUT_FILE"
done <"$IMAGE_DATA_FILE"

[[ "$INDEX" -eq "$COUNT" ]] ||
  die "Expected $COUNT images but received $INDEX"
