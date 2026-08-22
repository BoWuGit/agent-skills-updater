#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Install the complete Agent Skills pack, its update command, and (on macOS) a
daily LaunchAgent.

Options:
  --hour H                 Daily update hour, 0-23 (default: 10).
  --minute M               Daily update minute, 0-59 (default: 0).
  --no-schedule            Do not install the macOS LaunchAgent.
  --no-update              Install commands without fetching skills now.
  --force                  Replace conflicting same-name skills.
  --with-sim-use-binary    Install/upgrade the sim-use CLI with Homebrew.
  -h, --help               Show this help.
EOF
}

hour=10
minute=0
schedule=1
run_update=1
force=0
install_sim_use_binary=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hour)
      hour="${2:-}"
      shift
      ;;
    --minute)
      minute="${2:-}"
      shift
      ;;
    --no-schedule)
      schedule=0
      ;;
    --no-update)
      run_update=0
      ;;
    --force)
      force=1
      ;;
    --with-sim-use-binary)
      install_sim_use_binary=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! "$hour" =~ ^[0-9]+$ ]] || ((10#$hour > 23)); then
  printf 'Invalid hour: %s\n' "$hour" >&2
  exit 2
fi
if [[ ! "$minute" =~ ^[0-9]+$ ]] || ((10#$minute > 59)); then
  printf 'Invalid minute: %s\n' "$minute" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runtime_parent="$HOME/.local/libexec"
runtime_root="$runtime_parent/agent-skills-updater"
data_root="${AGENT_SKILLS_DATA_HOME:-$HOME/.local/share/agent-skills-updater}"
local_bin="$HOME/.local/bin"
config_dir="$HOME/.config/agent-skills-updater"
config_file="$config_dir/config"
update_link="$local_bin/update-all-skills"

if [[ -e "$update_link" || -L "$update_link" ]]; then
  existing_target="$(readlink "$update_link" 2>/dev/null || true)"
  if [[ "$existing_target" != "$runtime_root/bin/update-all-skills" && "$force" -ne 1 ]]; then
    printf 'Refusing to replace existing command: %s\nUse --force to replace it.\n' "$update_link" >&2
    exit 1
  fi
fi

mkdir -p "$runtime_parent" "$data_root" "$local_bin" "$config_dir"
staging="$(mktemp -d "$runtime_parent/.agent-skills-updater.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$staging/bin"
cp "$repo_root/bin/update-all-skills" "$staging/bin/"
cp "$repo_root/bin/install-launch-agent" "$staging/bin/"
cp "$repo_root/bin/run-scheduled-update" "$staging/bin/"
cp -R "$repo_root/lib" "$staging/"
cp -R "$repo_root/updaters" "$staging/"
chmod 0755 "$staging/bin/"* "$staging/updaters/"*

rm -f "$update_link"
rm -rf "$runtime_root"
mv "$staging" "$runtime_root"
trap - EXIT
ln -s "$runtime_root/bin/update-all-skills" "$update_link"

if [[ ! -f "$config_file" ]]; then
  install -m 0644 "$repo_root/config.example" "$config_file"
fi

if [[ "$install_sim_use_binary" -eq 1 ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    printf 'Homebrew is required by --with-sim-use-binary.\n' >&2
    exit 1
  fi
  brew tap lycorp-jp/tap
  if brew list --formula lycorp-jp/tap/sim-use >/dev/null 2>&1; then
    brew upgrade lycorp-jp/tap/sim-use || true
  else
    brew install lycorp-jp/tap/sim-use
  fi
fi

update_status=0
if [[ "$run_update" -eq 1 ]]; then
  if [[ "$force" -eq 1 ]]; then
    export AGENT_SKILLS_FORCE=1
  fi
  "$local_bin/update-all-skills" || update_status=$?
fi

if [[ "$schedule" -eq 1 && "$(uname -s)" == "Darwin" ]]; then
  "$runtime_root/bin/install-launch-agent" \
    --hour "$hour" \
    --minute "$minute" \
    --update-command "$local_bin/update-all-skills"
elif [[ "$schedule" -eq 1 ]]; then
  printf 'Skipping schedule: launchd is only available on macOS.\n' >&2
fi

printf '\nAgent Skills pack installed.\n'
printf '  update command: %s\n' "$local_bin/update-all-skills"
printf '  configuration:  %s\n' "$config_file"
printf '  managed sources: %s\n' "$data_root"
if [[ "$update_status" -ne 0 ]]; then
  printf 'Initial update finished with status %d; review the output above.\n' "$update_status" >&2
fi
exit "$update_status"
