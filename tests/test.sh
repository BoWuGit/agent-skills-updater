#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$repo_root/bin/run-scheduled-update"
installer="$repo_root/bin/install-launch-agent"
example="$repo_root/examples/update-all-skills"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for script in "$runner" "$installer" "$example"; do
  bash -n "$script"
done

make_fixture() {
  local name="$1"
  local status="$2"
  cat >"$tmp_dir/$name" <<EOF
#!/usr/bin/env bash
echo "$name fixture"
exit $status
EOF
  chmod +x "$tmp_dir/$name"
}

assert_run_status() {
  local expected="$1"
  local command="$2"
  local logs="$tmp_dir/logs-$expected"
  local actual=0

  SKILL_UPDATE_COMMAND="$command" \
    SKILL_UPDATE_LOG_DIR="$logs" \
    SKILL_UPDATE_NOTIFICATIONS=0 \
    "$runner" || actual=$?

  [[ "$actual" -eq "$expected" ]]
  [[ "$(cat "$logs/latest-status")" -eq "$expected" ]]
  grep -q "fixture" "$logs/latest.log"
  grep -q "Exit status: $expected" "$logs/latest.log"
}

make_fixture success 0
make_fixture failure 1
make_fixture attention 2
assert_run_status 0 "$tmp_dir/success"
assert_run_status 1 "$tmp_dir/failure"
assert_run_status 2 "$tmp_dir/attention"

special_command="$tmp_dir/success & updater"
cp "$tmp_dir/success" "$special_command"
fake_home="$tmp_dir/home & test"
HOME="$fake_home" "$installer" \
  --hour 7 \
  --minute 5 \
  --update-command "$special_command" \
  --no-load \
  --no-test-notification

plist="$fake_home/Library/LaunchAgents/io.github.agent-skills-updater.plist"
[[ -x "$fake_home/.local/libexec/agent-skills-updater/run-scheduled-update" ]]
grep -q '<integer>7</integer>' "$plist"
grep -q '<integer>5</integer>' "$plist"
grep -q 'success &amp; updater' "$plist"
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$plist" >/dev/null
fi

if grep -R -E -n \
  --exclude='test.sh' \
  --exclude-dir='.git' \
  '/Users/|BEGIN (RSA |OPENSSH )?PRIVATE KEY|gh[opsu]_[A-Za-z0-9]' \
  "$repo_root"; then
  echo 'Potential private path or secret found.' >&2
  exit 1
fi

printf 'All tests passed.\n'
