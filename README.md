# AI Quota Optimizer

AI Quota Optimizer is a small macOS utility that automatically triggers an AI session early at 05:30, so the first 5-hour window ends before your main working hours begin.

## Installation

Clone the repo:

```bash
git clone https://github.com/lukatizzz/ai-quota-optimizer
cd ai-quota-optimizer
```

Install the LaunchAgent:

```bash
./setup.sh install
```

To wake the machine from sleep at 05:25 on weekdays:

```bash
sudo ./setup.sh setup-wake
```

Check status:

```bash
./setup.sh status
```

Run immediately:

```bash
./setup.sh run-now
```

View recent logs:

```bash
./setup.sh logs
```

The goal is to make use of quota windows like this:

- Session 1: 05:30 → 10:30
- Session 2: 10:30 → 15:30
- Session 3: 15:30 → 20:30

With a typical 08:00–18:00 work schedule, this gives better coverage of working hours compared to starting the first session only when you arrive at the office.

## How it works

The project has two main parts:

- A `launchd` LaunchAgent that runs the trigger script at 05:30, Monday through Friday.
- An optional `pmset repeat wake` schedule to wake the machine from sleep at 05:25.

The trigger script sends a short prompt to whichever tools are available:

- Claude Code CLI (`claude`)
- Codex CLI (`codex`)
- OpenAI API if `OPENAI_API_KEY` is set
- Anthropic API if `ANTHROPIC_API_KEY` is set

The script automatically prepends common user-level binary directories such as `$HOME/.local/bin` and `$HOME/bin` to `PATH`, so user-local Claude CLI installations are found when running under `launchd`.

## Requirements

- macOS
- At least one AI tool or API key you want to trigger
- `sudo` access if you want the machine to wake from sleep automatically

Verified environment:

- Claude Code CLI at `$HOME/.local/bin/claude`
- Codex CLI in non-interactive mode via `codex exec`

## Uninstall

Remove the LaunchAgent:

```bash
./setup.sh uninstall
```

If you previously enabled the wake schedule:

```bash
sudo ./setup.sh remove-wake
```

## Project structure

- `trigger-ai-session.sh`: sends a short request to an AI tool or API
- `setup.sh`: installer and utility commands
- `com.team.ai-quota-optimizer.plist`: LaunchAgent template, rendered at install time

## No hard-coded paths

`com.team.ai-quota-optimizer.plist` in the repo is a template with no personal paths embedded.

When you run `./setup.sh install`, the script:

- sets `WorkingDirectory` to the actual repo directory on your machine
- sets the log path based on `$HOME`
- copies the rendered file to `~/Library/LaunchAgents/`

This means anyone can clone the repo into any directory and install it without modification.

## Practical notes

- `launchd` does not wake the machine. If the machine is asleep and you want the job to run at 05:30, enable `setup-wake`.
- `wake` only applies when the machine is sleeping. If it is fully shut down, a different mechanism (e.g. `poweron`) is needed, and hardware must support it.
- For Codex CLI, the project uses `codex exec` for non-interactive mode instead of deprecated options like `--quiet`.
- CLI syntax may change across versions. If your tool is not `claude` or `codex`, edit `trigger-ai-session.sh` accordingly.
- This project does not handle weekly usage limits. It only optimizes the rolling 5-hour daily window.

## Example workflow

The night before:

```bash
./setup.sh status
```

In the morning:

- 05:25 machine wakes from sleep
- 05:30 script triggers AI tool automatically
- 08:00–09:00 you start work, session 1 is already partially through
- 10:30 session 2 begins
- 15:30 session 3 begins

## Security

- Do not commit API keys to the repo.
- If using APIs directly, export keys via your shell profile or a local secrets file.
- Review logs before sharing them, as they may contain CLI output.

## License

Released under the MIT License. See the `LICENSE` file for details.