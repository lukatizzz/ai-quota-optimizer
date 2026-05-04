# AI Quota Optimizer

AI Quota Optimizer là một utility nhỏ cho macOS để tự động "đốt" session quota sớm vào khoảng 05:30 sáng, nhờ đó cửa sổ 5 giờ đầu tiên kết thúc trước giờ làm việc chính.

## Quick Start

```bash
git clone https://github.com/lukatizzz/ai-quota-optimizer
cd ai-quota-optimizer
./setup.sh install
./setup.sh run-now
./setup.sh status
./setup.sh logs
```

Nếu muốn máy tự wake khỏi sleep lúc 05:25 sáng các ngày làm việc:

```bash
sudo ./setup.sh setup-wake
```

Mục tiêu là tận dụng quota theo cách này:

- Session 1: 05:30 -> 10:30
- Session 2: 10:30 -> 15:30
- Session 3: 15:30 -> 20:30

Với lịch làm việc phổ biến 08:00-18:00 và nghỉ trưa 11:50-12:50, cách này giúp phủ tốt hơn giờ làm việc so với việc chỉ bắt đầu session đầu tiên khi vào công ty.

## Cách hoạt động

Project gồm 2 phần chính:

- `launchd` LaunchAgent chạy script vào 05:30 từ thứ Hai đến thứ Sáu.
- `pmset repeat wake` có thể được bật thêm để máy tự wake khỏi sleep vào 05:25.

Script trigger sẽ thử gửi một prompt rất ngắn tới các công cụ khả dụng như:

- Claude Code CLI (`claude`)
- Codex CLI (`codex`)
- OpenAI API nếu có `OPENAI_API_KEY`
- Anthropic API nếu có `ANTHROPIC_API_KEY`

Hiện tại script đã tự bổ sung các thư mục binary user-level phổ biến như `$HOME/.local/bin` và `$HOME/bin`, nên các bản cài Claude CLI kiểu user-local vẫn được nhận diện khi chạy qua `launchd`.

## Yêu cầu

- macOS
- Có sẵn ít nhất một AI tool hoặc API key mà bạn muốn trigger
- Nếu muốn máy tự wake khỏi sleep: cần quyền `sudo`

Ví dụ môi trường đã được kiểm chứng:

- Claude Code CLI tại `$HOME/.local/bin/claude`
- Codex CLI với chế độ non-interactive qua `codex exec`

## Gỡ cài đặt

Gỡ LaunchAgent:

```bash
./setup.sh uninstall
```

Nếu trước đó đã bật wake schedule:

```bash
sudo ./setup.sh remove-wake
```

## Cấu trúc project

- `trigger-ai-session.sh`: script gửi request ngắn tới AI tool/API
- `setup.sh`: installer và utility commands
- `com.team.ai-quota-optimizer.plist`: template LaunchAgent, được render khi cài đặt

## Cách project tránh hard-code máy cá nhân

File `com.team.ai-quota-optimizer.plist` trong repo là template, không chứa trực tiếp đường dẫn cá nhân.

Khi chạy `./setup.sh install`, script sẽ:

- render `WorkingDirectory` theo thư mục thực tế của repo trên máy người dùng
- render đường dẫn log theo `$HOME`
- copy file hoàn chỉnh vào `~/Library/LaunchAgents/`

Nhờ đó mọi người có thể clone repo vào bất kỳ thư mục nào rồi cài đặt.

## Lưu ý thực tế

- `launchd` không thay thế việc wake máy. Nếu máy đang sleep và bạn muốn job chạy đúng 05:30, nên bật `setup-wake`.
- `wake` chỉ áp dụng khi máy đang sleep. Nếu máy shutdown hoàn toàn, cần cơ chế khác như `poweron` và phần cứng phải hỗ trợ.
- Với Codex CLI, project hiện dùng `codex exec` cho chế độ non-interactive thay vì các option cũ như `--quiet`.
- Một số CLI có thể thay đổi cú pháp theo phiên bản. Nếu tool của bạn không phải `claude` hoặc `codex`, hãy sửa `trigger-ai-session.sh` cho phù hợp.
- Project này không xử lý weekly usage limit. Nó chỉ tối ưu cửa sổ rolling 5 giờ theo ngày.

## Ví dụ workflow

Buổi tối trước khi ngủ:

```bash
./setup.sh status
```

Buổi sáng:

- 05:25 máy tự wake
- 05:30 script tự trigger AI tool
- 08:00-09:00 bắt đầu làm việc nhưng session 1 đã chạy được một phần
- 10:30 reset sang session 2
- 15:30 reset sang session 3

## Bảo mật

- Không commit API key vào repo.
- Nếu dùng API trực tiếp, ưu tiên export biến môi trường trong shell profile hoặc cấu hình secret cục bộ.
- Kiểm tra lại log trước khi chia sẻ nếu log có thể chứa output từ CLI.

## Giấy phép

Phát hành theo giấy phép MIT. Xem file `LICENSE` để biết chi tiết.