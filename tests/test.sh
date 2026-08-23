#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$repo_root/bin/run-scheduled-update"
launch_installer="$repo_root/bin/install-launch-agent"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

while IFS= read -r script; do
  bash -n "$script"
done < <(find \
  "$repo_root/bin" \
  "$repo_root/updaters" \
  "$repo_root/lib" \
  "$repo_root/examples" \
  -type f)
bash -n "$repo_root/install.sh"

make_command_fixture() {
  local name="$1"
  local status="$2"
  cat >"$tmp_dir/$name" <<EOF
#!/usr/bin/env bash
echo "$name fixture"
exit $status
EOF
  chmod +x "$tmp_dir/$name"
}

assert_scheduled_status() {
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

make_command_fixture success 0
make_command_fixture failure 1
make_command_fixture attention 2
assert_scheduled_status 0 "$tmp_dir/success"
assert_scheduled_status 1 "$tmp_dir/failure"
assert_scheduled_status 2 "$tmp_dir/attention"

launch_home="$tmp_dir/launch home & test"
HOME="$launch_home" "$launch_installer" \
  --hour 7 \
  --minute 5 \
  --update-command "$tmp_dir/success" \
  --no-load \
  --no-test-notification

plist="$launch_home/Library/LaunchAgents/io.github.agent-skills-updater.plist"
[[ -x "$launch_home/.local/libexec/agent-skills-updater/run-scheduled-update" ]]
grep -q '<integer>7</integer>' "$plist"
grep -q '<integer>5</integer>' "$plist"
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$plist" >/dev/null
fi

create_git_fixture() {
  local repository="$1"
  mkdir -p "$repository"
  git -C "$repository" init -q -b main
  git -C "$repository" config user.name test
  git -C "$repository" config user.email test@example.invalid
}

fixture_root="$tmp_dir/upstreams"
mkdir -p "$fixture_root"
cat >"$fixture_root/thermo-SKILL.md" <<'EOF'
---
name: thermo-nuclear-code-quality-review
description: Test fixture.
---
# Thermo fixture
EOF
cat >"$fixture_root/code-simplifier.md" <<'EOF'
---
name: code-simplifier
description: Official test fixture.
model: opus
---
# Code simplifier fixture
EOF

sim_repo="$fixture_root/sim-use"
create_git_fixture "$sim_repo"
mkdir -p "$sim_repo/skills/sim-use/scripts"
cat >"$sim_repo/skills/sim-use/SKILL.md" <<'EOF'
---
name: sim-use
description: Test fixture.
---
EOF
printf 'print("fixture")\n' >"$sim_repo/skills/sim-use/scripts/preflight.py"
git -C "$sim_repo" add .
git -C "$sim_repo" commit -qm fixture

openclaw_repo="$fixture_root/openclaw"
create_git_fixture "$openclaw_repo"
mkdir -p "$openclaw_repo/skills/autoreview"
cat >"$openclaw_repo/skills/autoreview/SKILL.md" <<'EOF'
---
name: autoreview
description: Test fixture.
---
EOF
git -C "$openclaw_repo" add .
git -C "$openclaw_repo" commit -qm fixture

matt_repo="$fixture_root/matt"
create_git_fixture "$matt_repo"
mkdir -p "$matt_repo/skills/engineering/fixture-skill" \
  "$matt_repo/skills/deprecated/old-skill"
cat >"$matt_repo/skills/engineering/fixture-skill/SKILL.md" <<'EOF'
---
name: fixture-skill
description: Test fixture.
---
EOF
cp "$matt_repo/skills/engineering/fixture-skill/SKILL.md" \
  "$matt_repo/skills/deprecated/old-skill/SKILL.md"
git -C "$matt_repo" add .
git -C "$matt_repo" commit -qm fixture

pack_home="$tmp_dir/pack-home"
mkdir -p "$pack_home/.claude" "$pack_home/.codex" "$pack_home/.dsh"
HOME="$pack_home" \
DSH_HOME='   ' \
THERMO_SKILL_URL="file://$fixture_root/thermo-SKILL.md" \
AGENT_SKILLS_CURL_PROTOCOLS='=https,file' \
SIM_USE_REPO_URL="$sim_repo" \
OPENCLAW_SKILLS_REPO_URL="$openclaw_repo" \
MATTPOCOCK_SKILLS_REPO_URL="$matt_repo" \
CODE_SIMPLIFIER_SKILL_URL="file://$fixture_root/code-simplifier.md" \
  "$repo_root/install.sh" --no-schedule

update_command="$pack_home/.local/bin/update-all-skills"
[[ -x "$update_command" ]]
for target in \
  "$pack_home/.agents/skills" \
  "$pack_home/.claude/skills" \
  "$pack_home/.codex/skills" \
  "$pack_home/.dsh/skills"; do
  [[ -L "$target/thermo-nuclear-code-quality-review" ]]
  [[ -L "$target/sim-use" ]]
  [[ -L "$target/autoreview" ]]
  [[ -L "$target/fixture-skill" ]]
  [[ -L "$target/code-simplifier" ]]
  grep -q '^model: opus$' "$target/code-simplifier/SKILL.md"
  [[ ! -e "$target/old-skill" ]]
done
"$update_command" --dry-run >/dev/null

# A nonblank DSH_HOME replaces the default DSH root, and ~/ expands like dsh.
custom_dsh_home="$pack_home/custom-dsh-home"
mkdir -p "$custom_dsh_home"
custom_targets="$(
  HOME="$pack_home" DSH_HOME='~/custom-dsh-home' bash -c '
    source "$1/lib/common.sh"
    agent_skill_targets
  ' _ "$repo_root"
)"
printf '%s\n' "$custom_targets" | grep -Fxq "$custom_dsh_home/skills"
if printf '%s\n' "$custom_targets" | grep -Fxq "$pack_home/.dsh/skills"; then
  echo 'Default DSH target remained active beside a custom DSH_HOME.' >&2
  exit 1
fi

# Reinstalling a managed pack is idempotent and does not require --force.
HOME="$pack_home" "$repo_root/install.sh" --no-schedule --no-update >/dev/null
[[ -x "$update_command" ]]

if grep -R -E -n \
  --exclude='test.sh' \
  --exclude-dir='.git' \
  '/Users/|BEGIN (RSA |OPENSSH )?PRIVATE KEY|gh[opsu]_[A-Za-z0-9]' \
  "$repo_root"; then
  echo 'Potential private path or secret found.' >&2
  exit 1
fi

printf 'All tests passed.\n'
