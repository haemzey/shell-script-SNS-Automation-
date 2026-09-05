#!/usr/bin/env bash

set -Eeuo pipefail

readonly SNS_TOPIC_ARN="${SNS_TOPIC_ARN:?SNS_TOPIC_ARN environment variable is required}"
readonly AWS_REGION="${AWS_REGION:-us-east-1}"

log() {
    printf '[INFO] %s\n' "$*"
}

error() {
    printf '[ERROR] %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

trap 'error "Command failed at line $LINENO: $BASH_COMMAND"' ERR

# ------------------------------------------------------------
# Validate dependencies
# ------------------------------------------------------------

command -v aws >/dev/null 2>&1 ||
    die "AWS CLI is not installed."

command -v jq >/dev/null 2>&1 ||
    die "jq is not installed."

# ------------------------------------------------------------
# Validate event input
# ------------------------------------------------------------

EVENT_FILE="${1:-}"

[[ -f "$EVENT_FILE" ]] ||
    die "Usage: $0 <s3-event.json>"

# ------------------------------------------------------------
# Extract S3 event information
# ------------------------------------------------------------

BUCKET_NAME="$(
    jq -r '.Records[0].s3.bucket.name // empty' "$EVENT_FILE"
)"

OBJECT_KEY="$(
    jq -r '.Records[0].s3.object.key // empty' "$EVENT_FILE"
)"

[[ -n "$BUCKET_NAME" ]] ||
    die "S3 bucket name not found in event."

[[ -n "$OBJECT_KEY" ]] ||
    die "S3 object key not found in event."

# ------------------------------------------------------------
# Application logging
# ------------------------------------------------------------

log "S3 object created"
log "Bucket : $BUCKET_NAME"
log "Object : $OBJECT_KEY"

# ------------------------------------------------------------
# Publish SNS notification
# ------------------------------------------------------------

MESSAGE="File '${OBJECT_KEY}' was uploaded to bucket '${BUCKET_NAME}'."

aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "S3 Object Created" \
    --message "$MESSAGE" \
    --region "$AWS_REGION" \
    >/dev/null

log "SNS notification published successfully."

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

log "S3 event processing completed successfully."

exit 0