#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.team.ai-quota-optimizer.plist"
PLIST_TEMPLATE="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
TRIGGER_SCRIPT="$SCRIPT_DIR/trigger-ai-session.sh"
LOG_DIR="$HOME/.ai-quota-optimizer/logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; }

usage() {
	cat <<EOF
Usage: $0 [command]

Commands:
  install      Render plist and install LaunchAgent
  uninstall    Remove LaunchAgent
  status       Show current status
  setup-wake   Enable wake-from-sleep at 05:25 Mon-Fri (requires sudo)
  remove-wake  Disable wake schedule (requires sudo)
  run-now      Run the trigger immediately
  logs         Show the most recent log
EOF
}

render_plist() {
	[[ -f "$PLIST_TEMPLATE" ]] || { error "Template not found: $PLIST_TEMPLATE"; exit 1; }

	mkdir -p "$(dirname "$PLIST_DEST")"
	sed \
		-e "s|__WORKDIR__|$SCRIPT_DIR|g" \
		-e "s|__HOME__|$HOME|g" \
		"$PLIST_TEMPLATE" > "$PLIST_DEST"
}

do_install() {
	info "=== Installing AI Quota Optimizer ==="

	[[ -f "$TRIGGER_SCRIPT" ]] || { error "Script not found: $TRIGGER_SCRIPT"; exit 1; }

	chmod +x "$TRIGGER_SCRIPT" "$SCRIPT_DIR/setup.sh"
	mkdir -p "$LOG_DIR"
	render_plist

	launchctl unload "$PLIST_DEST" 2>/dev/null || true
	if launchctl load "$PLIST_DEST"; then
		success "LaunchAgent installed: $PLIST_DEST"
	else
		error "Failed to load LaunchAgent"
		exit 1
	fi

	warn "To wake the machine from sleep at 05:25, run: sudo $0 setup-wake"
}

do_setup_wake() {
	info "Configuring wake schedule: Mon-Fri at 05:25..."

	if [[ "$EUID" -ne 0 ]]; then
		error "This command requires sudo. Run: sudo $0 setup-wake"
		exit 1
	fi

	pmset repeat wake MTWRF 05:25:00
	success "Wake schedule set: Mon-Fri at 05:25"
	pmset -g sched
}

do_remove_wake() {
	info "Removing wake schedule..."

	if [[ "$EUID" -ne 0 ]]; then
		error "This command requires sudo. Run: sudo $0 remove-wake"
		exit 1
	fi

	pmset repeat cancel
	success "Wake schedule removed"
}

do_uninstall() {
	info "Uninstalling AI Quota Optimizer..."

	if [[ -f "$PLIST_DEST" ]]; then
		launchctl unload "$PLIST_DEST" 2>/dev/null || true
		rm -f "$PLIST_DEST"
		success "LaunchAgent removed"
	else
		warn "LaunchAgent is not installed"
	fi

	warn "If you enabled the wake schedule, also run: sudo $0 remove-wake"
}

do_status() {
	info "=== AI Quota Optimizer Status ==="
	echo

	if [[ -f "$PLIST_DEST" ]]; then
		success "LaunchAgent plist: INSTALLED ($PLIST_DEST)"
	else
		warn "LaunchAgent plist: NOT INSTALLED"
	fi

	echo
	info "pmset wake schedule:"
	local wake_sched
	wake_sched="$(pmset -g sched 2>/dev/null || true)"
	if echo "$wake_sched" | grep -qE "5:25AM|05:25"; then
		success "  Wake 05:25 Mon-Fri: ENABLED"
	else
		warn "  Wake schedule not configured → run: sudo $0 setup-wake"
		[[ -n "$wake_sched" ]] && echo "$wake_sched"
	fi

	echo
	info "LaunchAgent status:"
	launchctl list | grep "com.team.ai-quota-optimizer" || warn "  Not loaded in launchctl"

	echo
	local latest_log
	latest_log="$(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -1 || true)"
	if [[ -n "$latest_log" ]]; then
		info "Most recent log: $latest_log"
		tail -5 "$latest_log"
	else
		warn "No logs found"
	fi
}

do_run_now() {
	info "Running trigger manually..."
	bash "$TRIGGER_SCRIPT"
}

do_logs() {
	local latest_log
	latest_log="$(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -1 || true)"
	if [[ -n "$latest_log" ]]; then
		cat "$latest_log"
	else
		warn "No logs found"
	fi
}

cmd="${1:-install}"
case "$cmd" in
	install)     do_install ;;
	uninstall)   do_uninstall ;;
	status)      do_status ;;
	setup-wake)  do_setup_wake ;;
	remove-wake) do_remove_wake ;;
	run-now)     do_run_now ;;
	logs)        do_logs ;;
	-h|--help)   usage ;;
	*) error "Unknown command: $cmd"; usage; exit 1 ;;
esac
