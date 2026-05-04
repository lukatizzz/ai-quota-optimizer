#!/usr/bin/env bash
# =============================================================================
# AI Quota Optimizer - Session Trigger Script
# =============================================================================
# Purpose: Automatically send a short message to AI tools at 05:30
#          to start the 5-hour usage window before working hours begin.
#
# Quota strategy:
#   Session 1 (auto): 05:30 → 10:30  (window ends before peak hours)
#   Session 2 (work): 10:30 → 15:30  (morning + afternoon peak)
#   Session 3 (work): 15:30 → 20:30  (late work hours + buffer)
#   ⇒ 3 sessions instead of 2 if starting at 08:00–09:00
# =============================================================================

set -euo pipefail

# Prepend common user-level binary directories that launchd typically omits.
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# --- Configuration ---
LOG_DIR="$HOME/.ai-quota-optimizer/logs"
LOG_FILE="$LOG_DIR/session-$(date +%Y-%m-%d).log"
TRIGGER_MESSAGE="hello"

# Create log directory if it does not exist
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "========================================="
log "AI Quota Optimizer - Session Trigger"
log "========================================="

# =============================================================================
# CLAUDE CODE
# =============================================================================
trigger_claude_code() {
    log "[Claude Code] Checking availability..."

    if ! command -v claude &>/dev/null; then
        log "[Claude Code] SKIP - 'claude' CLI not found"
        return
    fi

    log "[Claude Code] Triggering session..."

    # Send a short message, no lengthy output needed → saves tokens
    # --print: non-interactive mode (no editor opened)
    # timeout 30s to prevent hanging; use temp file to filter "Execution error" noise
    local tmp_out
    tmp_out=$(mktemp)
    if timeout 30 claude --print "$TRIGGER_MESSAGE. Respond with just 'ok'." > "$tmp_out" 2>&1; then
        grep -v '^Execution error' "$tmp_out" >> "$LOG_FILE" || true
        log "[Claude Code] SUCCESS - Session window started"
    else
        cat "$tmp_out" >> "$LOG_FILE"
        log "[Claude Code] FAILED - exit code $?"
    fi
    rm -f "$tmp_out"
}

# =============================================================================
# OPENAI CODEX / CHATGPT CLI
# =============================================================================
trigger_codex() {
    log "[Codex/ChatGPT] Checking availability..."

    if ! command -v codex &>/dev/null; then
        log "[Codex] SKIP - 'codex' CLI not found"
        return
    fi

    log "[Codex] Triggering session..."

    if codex exec "$TRIGGER_MESSAGE" >> "$LOG_FILE" 2>&1; then
        log "[Codex] SUCCESS - Session window started"
    else
        log "[Codex] FAILED - exit code $?"
    fi
}

# =============================================================================
# OPENAI API (direct, using API key)
# =============================================================================
trigger_openai_api() {
    log "[OpenAI API] Checking availability..."

    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        log "[OpenAI API] SKIP - OPENAI_API_KEY not set"
        return
    fi

    if ! command -v curl &>/dev/null; then
        log "[OpenAI API] SKIP - curl not found"
        return
    fi

    log "[OpenAI API] Triggering session..."

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d '{
            "model": "gpt-4o",
            "max_tokens": 5,
            "messages": [{"role": "user", "content": "hi"}]
        }')

    if [[ "$HTTP_STATUS" == "200" ]]; then
        log "[OpenAI API] SUCCESS - HTTP $HTTP_STATUS"
    else
        log "[OpenAI API] FAILED - HTTP $HTTP_STATUS"
    fi
}

# =============================================================================
# ANTHROPIC API (direct, using API key)
# =============================================================================
trigger_anthropic_api() {
    log "[Anthropic API] Checking availability..."

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        log "[Anthropic API] SKIP - ANTHROPIC_API_KEY not set"
        return
    fi

    log "[Anthropic API] Triggering session..."

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-opus-4-5",
            "max_tokens": 5,
            "messages": [{"role": "user", "content": "hi"}]
        }')

    if [[ "$HTTP_STATUS" == "200" ]]; then
        log "[Anthropic API] SUCCESS - HTTP $HTTP_STATUS"
    else
        log "[Anthropic API] FAILED - HTTP $HTTP_STATUS"
    fi
}

# =============================================================================
# Run all triggers
# =============================================================================
main() {
    log "Starting session triggers..."

    trigger_claude_code
    trigger_codex
    trigger_openai_api
    trigger_anthropic_api

    log "All triggers completed."
    log "Next session reset expected around: $(date -v+5H '+%H:%M')"
}

main
