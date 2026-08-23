#!/usr/bin/env bash

agent_skills_data_home() {
  printf '%s\n' "${AGENT_SKILLS_DATA_HOME:-$HOME/.local/share/agent-skills-updater}"
}

agent_skills_source_home() {
  printf '%s/sources\n' "$(agent_skills_data_home)"
}

agent_skill_targets() {
  if [[ -n "${AGENT_SKILLS_TARGETS:-}" ]]; then
    local configured_targets=()
    IFS=':' read -r -a configured_targets <<<"$AGENT_SKILLS_TARGETS"
    printf '%s\n' "${configured_targets[@]}"
    return
  fi

  # ~/.agents is the cross-harness baseline. Add harness-specific roots only
  # when their parent configuration directory already exists.
  local dsh_home="$HOME/.dsh"
  if [[ -n "${DSH_HOME:-}" && "${DSH_HOME//[[:space:]]/}" != "" ]]; then
    dsh_home="$DSH_HOME"
  fi
  if [[ "$dsh_home" == "~" ]]; then
    dsh_home="$HOME"
  elif [[ "$dsh_home" == "~/"* ]]; then
    dsh_home="$HOME/${dsh_home#\~/}"
  fi

  printf '%s\n' "$HOME/.agents/skills"
  [[ -d "$HOME/.claude" ]] && printf '%s\n' "$HOME/.claude/skills"
  [[ -d "$HOME/.codex" ]] && printf '%s\n' "$HOME/.codex/skills"
  [[ -d "$HOME/.config/agents" ]] && printf '%s\n' "$HOME/.config/agents/skills"
  [[ -d "$HOME/.pi/agent" ]] && printf '%s\n' "$HOME/.pi/agent/skills"
  [[ -d "$HOME/.cursor" ]] && printf '%s\n' "$HOME/.cursor/skills"
  [[ -d "$dsh_home" ]] && printf '%s\n' "$dsh_home/skills"
}

link_skill_to_targets() {
  local source="$1"
  local skill_name="${2:-$(basename "$source")}"
  local managed_root
  managed_root="$(agent_skills_data_home)"

  if [[ ! -f "$source/SKILL.md" ]]; then
    printf 'Skill source has no SKILL.md: %s\n' "$source" >&2
    return 1
  fi

  local linked=0
  local skipped=0
  local target_root destination existing_source
  while IFS= read -r target_root; do
    [[ -n "$target_root" ]] || continue
    mkdir -p "$target_root"
    destination="$target_root/$skill_name"

    if [[ -L "$destination" ]]; then
      existing_source="$(readlink "$destination" || true)"
      if [[ "$existing_source" == "$source" || "$existing_source" == "$managed_root"/* ]]; then
        ln -sfn "$source" "$destination"
        linked=$((linked + 1))
      elif [[ "${AGENT_SKILLS_FORCE:-0}" == "1" ]]; then
        ln -sfn "$source" "$destination"
        linked=$((linked + 1))
      else
        printf 'skip unmanaged symlink: %s -> %s\n' "$destination" "$existing_source" >&2
        skipped=$((skipped + 1))
      fi
    elif [[ -e "$destination" ]]; then
      if [[ "${AGENT_SKILLS_FORCE:-0}" == "1" ]]; then
        rm -rf "$destination"
        ln -s "$source" "$destination"
        linked=$((linked + 1))
      else
        printf 'skip existing non-symlink: %s\n' "$destination" >&2
        skipped=$((skipped + 1))
      fi
    else
      ln -s "$source" "$destination"
      linked=$((linked + 1))
    fi
  done < <(agent_skill_targets)

  printf '  %s: linked to %d target(s), skipped %d conflict(s)\n' \
    "$skill_name" "$linked" "$skipped"
}

update_shallow_checkout() {
  local repository="$1"
  local url="$2"
  local ref="${3:-main}"

  mkdir -p "$(dirname "$repository")"
  if [[ ! -d "$repository/.git" ]]; then
    rm -rf "$repository"
    git init -q "$repository"
    git -C "$repository" remote add origin "$url"
  elif [[ "$(git -C "$repository" remote get-url origin 2>/dev/null || true)" != "$url" ]]; then
    git -C "$repository" remote set-url origin "$url"
  fi

  git -C "$repository" fetch --depth 1 origin "$ref"
  git -C "$repository" checkout -q --detach FETCH_HEAD
  git -C "$repository" reset --hard -q FETCH_HEAD
  git -C "$repository" rev-parse --short HEAD
}
