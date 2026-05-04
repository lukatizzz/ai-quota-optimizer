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
  install      Render plist và cài LaunchAgent
  uninstall    Gỡ LaunchAgent
  status       Kiểm tra trạng thái
  setup-wake   Bật wake-from-sleep lúc 05:25 T2-T6 (cần sudo)
  remove-wake  Tắt wake schedule (cần sudo)
  run-now      Chạy trigger ngay lập tức
  logs         Xem log gần nhất
EOF
}

render_plist() {
	[[ -f "$PLIST_TEMPLATE" ]] || { error "Không tìm thấy template: $PLIST_TEMPLATE"; exit 1; }

	mkdir -p "$(dirname "$PLIST_DEST")"
	sed \
		-e "s|__WORKDIR__|$SCRIPT_DIR|g" \
		-e "s|__HOME__|$HOME|g" \
		"$PLIST_TEMPLATE" > "$PLIST_DEST"
}

do_install() {
	info "=== Cài đặt AI Quota Optimizer ==="

	[[ -f "$TRIGGER_SCRIPT" ]] || { error "Không tìm thấy script: $TRIGGER_SCRIPT"; exit 1; }

	chmod +x "$TRIGGER_SCRIPT" "$SCRIPT_DIR/setup.sh"
	mkdir -p "$LOG_DIR"
	render_plist

	launchctl unload "$PLIST_DEST" 2>/dev/null || true
	if launchctl load "$PLIST_DEST"; then
		success "Đã cài LaunchAgent: $PLIST_DEST"
	else
		error "Không thể load LaunchAgent"
		exit 1
	fi

	warn "Nếu muốn máy tự wake từ sleep lúc 05:25, chạy: sudo $0 setup-wake"
}

do_setup_wake() {
	info "Cấu hình wake schedule: T2-T6 lúc 05:25..."

	if [[ "$EUID" -ne 0 ]]; then
		error "Lệnh này cần sudo. Hãy chạy: sudo $0 setup-wake"
		exit 1
	fi

	pmset repeat wake MTWRF 05:25:00
	success "Đã đặt wake schedule: T2-T6 lúc 05:25"
	pmset -g sched
}

do_remove_wake() {
	info "Xóa wake schedule..."

	if [[ "$EUID" -ne 0 ]]; then
		error "Lệnh này cần sudo. Hãy chạy: sudo $0 remove-wake"
		exit 1
	fi

	pmset repeat cancel
	success "Đã xóa wake schedule"
}

do_uninstall() {
	info "Gỡ AI Quota Optimizer..."

	if [[ -f "$PLIST_DEST" ]]; then
		launchctl unload "$PLIST_DEST" 2>/dev/null || true
		rm -f "$PLIST_DEST"
		success "Đã gỡ LaunchAgent"
	else
		warn "LaunchAgent chưa được cài"
	fi

	warn "Nếu đã bật wake schedule, chạy thêm: sudo $0 remove-wake"
}

do_status() {
	info "=== Trạng thái AI Quota Optimizer ==="
	echo

	if [[ -f "$PLIST_DEST" ]]; then
		success "LaunchAgent plist: CÓ ($PLIST_DEST)"
	else
		warn "LaunchAgent plist: CHƯA CÀI ĐẶT"
	fi

	echo
	info "pmset wake schedule:"
	local wake_sched
	wake_sched="$(pmset -g sched 2>/dev/null || true)"
	if echo "$wake_sched" | grep -qE "5:25AM|05:25"; then
		success "  Wake 05:25 T2-T6: ĐÃ BẬT"
	else
		warn "  Wake schedule chưa cấu hình → chạy: sudo $0 setup-wake"
		[[ -n "$wake_sched" ]] && echo "$wake_sched"
	fi

	echo
	info "LaunchAgent status:"
	launchctl list | grep "com.team.ai-quota-optimizer" || warn "  Chưa được load vào launchctl"

	echo
	local latest_log
	latest_log="$(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -1 || true)"
	if [[ -n "$latest_log" ]]; then
		info "Log gần nhất: $latest_log"
		tail -5 "$latest_log"
	else
		warn "Chưa có log nào"
	fi
}

do_run_now() {
	info "Chạy trigger thủ công..."
	bash "$TRIGGER_SCRIPT"
}

do_logs() {
	local latest_log
	latest_log="$(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -1 || true)"
	if [[ -n "$latest_log" ]]; then
		cat "$latest_log"
	else
		warn "Chưa có log nào"
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
