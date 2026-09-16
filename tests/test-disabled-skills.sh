#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Only exercise common linking against local fixtures, never an updater or
# the caller's config, targets, or source checkout.
export HOME="$tmp_dir/home"
export AGENT_SKILLS_DATA_HOME="$HOME/data"
unset AGENT_SKILLS_TARGETS AGENT_SKILLS_DISABLED AGENT_SKILLS_FORCE DSH_HOME
source "$repo_root/lib/common.sh"

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]]
}

source_dir="$AGENT_SKILLS_DATA_HOME/sources/fixture-skill"
mkdir -p "$source_dir"
printf 'Unmodified upstream fixture\n' >"$source_dir/SKILL.md"
cp "$source_dir/SKILL.md" "$tmp_dir/original"
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.config/agents" \
  "$HOME/.cursor" "$HOME/custom dsh" "$HOME/.pi/agent/skills"
export DSH_HOME="$HOME/custom dsh"
targets=()
while IFS= read -r target; do targets+=("$target"); done < <(agent_skill_targets)
[[ "${#targets[@]}" -eq 6 ]]
pi_alias="$HOME/.pi/agent/skills/fixture-skill"

# Unset defaults to enabled. Disable across every detected target, including
# stale managed links and the old native Pi alias, then enable again.
link_skill_to_targets "$source_dir"
for target in "${targets[@]}"; do
  [[ "$(readlink "$target/fixture-skill")" == "$source_dir" ]]
done
ln -sfn "$AGENT_SKILLS_DATA_HOME/sources/missing" "${targets[1]}/fixture-skill"
ln -s "$source_dir" "$pi_alias"
export AGENT_SKILLS_DISABLED=$'other\tfixture-skill\nlast'
link_skill_to_targets "$source_dir"
link_skill_to_targets "$source_dir" # Idempotent.
for target in "${targets[@]}"; do assert_absent "$target/fixture-skill"; done
assert_absent "$pi_alias"
export AGENT_SKILLS_DISABLED=''
link_skill_to_targets "$source_dir"
for target in "${targets[@]}"; do [[ -L "$target/fixture-skill" ]]; done
assert_absent "$pi_alias"

# Exact matching: no prefix/suffix, case folding, regex, or glob expansion.
export AGENT_SKILLS_TARGETS="$HOME/exact target"
for disabled in 'fixture' 'fixture-skill-extra' 'prefix-fixture-skill' \
  'Fixture-skill' 'fixture-.*' 'fixture-*' '   '; do
  export AGENT_SKILLS_DISABLED="$disabled"
  link_skill_to_targets "$source_dir"
  [[ -L "$AGENT_SKILLS_TARGETS/fixture-skill" ]]
done
export AGENT_SKILLS_DISABLED='fixture-skill'
link_skill_to_targets "$source_dir" fixture-skill-extra
[[ -L "$AGENT_SKILLS_TARGETS/fixture-skill-extra" ]]
# Even metacharacters in a name are literal.
export AGENT_SKILLS_DISABLED='literalXskill'
link_skill_to_targets "$source_dir" 'literal.skill'
[[ -L "$AGENT_SKILLS_TARGETS/literal.skill" ]]
export AGENT_SKILLS_DISABLED='literal.skill'
link_skill_to_targets "$source_dir" 'literal.skill'
assert_absent "$AGENT_SKILLS_TARGETS/literal.skill"

# Explicit targets override detection, but disabled cleanup always includes
# the legacy default Pi alias. Also recognize an exact source outside data home.
external_source="$HOME/external source"
mkdir -p "$external_source"
cp "$tmp_dir/original" "$external_source/SKILL.md"
export AGENT_SKILLS_TARGETS="$HOME/custom one:$HOME/custom two:$HOME/not created"
mkdir -p "$HOME/custom one" "$HOME/custom two"
ln -s "$external_source" "$HOME/custom one/fixture-skill"
ln -s "$AGENT_SKILLS_DATA_HOME/sources/gone" "$HOME/custom two/fixture-skill"
ln -s "$AGENT_SKILLS_DATA_HOME/sources/gone" "$pi_alias"
export AGENT_SKILLS_DISABLED='fixture-skill'
link_skill_to_targets "$external_source" fixture-skill
assert_absent "$HOME/custom one/fixture-skill"
assert_absent "$HOME/custom two/fixture-skill"
assert_absent "$HOME/not created"
assert_absent "$pi_alias"
[[ -L "${targets[0]}/fixture-skill" ]] # Outside the configured target list.

# Preserve unmanaged symlinks (including dangling ones and data-home prefix
# lookalikes), files, and directories, even under FORCE. Pi gets the same rule.
export AGENT_SKILLS_FORCE=1
unmanaged="$HOME/user skill"
mkdir -p "$unmanaged"
printf 'user owned\n' >"$unmanaged/keep"
for kind in symlink dangling prefix file directory; do
  for target in "$HOME/custom one" "$HOME/.pi/agent/skills"; do
    destination="$target/fixture-skill"
    case "$kind" in
      symlink) ln -s "$unmanaged" "$destination" ;;
      dangling) ln -s "$HOME/missing user skill" "$destination" ;;
      prefix) ln -s "${AGENT_SKILLS_DATA_HOME}-other/skill" "$destination" ;;
      file) cp "$unmanaged/keep" "$destination" ;;
      directory) mkdir "$destination"; cp "$unmanaged/keep" "$destination/keep" ;;
    esac
  done
  link_skill_to_targets "$external_source" fixture-skill
  for target in "$HOME/custom one" "$HOME/.pi/agent/skills"; do
    destination="$target/fixture-skill"
    case "$kind" in
      symlink) [[ "$(readlink "$destination")" == "$unmanaged" ]] ;;
      dangling) [[ "$(readlink "$destination")" == "$HOME/missing user skill" ]] ;;
      prefix) [[ "$(readlink "$destination")" == "${AGENT_SKILLS_DATA_HOME}-other/skill" ]] ;;
      file) [[ ! -L "$destination" ]]; cmp "$unmanaged/keep" "$destination" ;;
      directory) [[ ! -L "$destination" ]]; cmp "$unmanaged/keep" "$destination/keep" ;;
    esac
    rm -rf "$destination"
  done
done

# A disabled missing source can still clean up dangling managed links.
ln -s "$AGENT_SKILLS_DATA_HOME/missing" "$HOME/custom one/fixture-skill"
link_skill_to_targets "$AGENT_SKILLS_DATA_HOME/missing" fixture-skill
assert_absent "$HOME/custom one/fixture-skill"
# Re-enabling with custom targets restores links without modifying payloads.
unset AGENT_SKILLS_DISABLED
link_skill_to_targets "$external_source" fixture-skill
for target in "$HOME/custom one" "$HOME/custom two" "$HOME/not created"; do
  [[ "$(readlink "$target/fixture-skill")" == "$external_source" ]]
done
cmp "$tmp_dir/original" "$source_dir/SKILL.md"
cmp "$tmp_dir/original" "$external_source/SKILL.md"
printf 'Disabled skill tests passed.\n'
