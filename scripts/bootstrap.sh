#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$workspace_root/repositories.tsv"
lock_path="$workspace_root/repositories.lock"
use_lock=false

if [[ "${1:-}" == "--locked" ]]; then
  use_lock=true
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--locked]" >&2
  exit 2
fi

if [[ "$use_lock" == true && ! -f "$lock_path" ]]; then
  echo "missing lock file: $lock_path" >&2
  exit 1
fi

while IFS=$'\t' read -r repo_name repo_path repo_url default_ref repo_role; do
  [[ -z "$repo_name" || "$repo_name" == \#* ]] && continue
  if [[ "$repo_path" == /* || "$repo_path" == *".."* ]]; then
    echo "unsafe repository path for $repo_name: $repo_path" >&2
    exit 1
  fi

  target_path="$workspace_root/$repo_path"
  if [[ -d "$target_path/.git" ]]; then
    echo "exists: $repo_name ($repo_path)"
    continue
  fi
  if [[ -e "$target_path" && -n "$(find "$target_path" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "target path is not empty: $target_path" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_path")"
  echo "cloning: $repo_name ($default_ref)"
  git clone --branch "$default_ref" --single-branch "$repo_url" "$target_path"

  if [[ "$use_lock" == true ]]; then
    locked_commit="$(awk -F '\t' -v name="$repo_name" '$1 == name {print $2}' "$lock_path")"
    if [[ -z "$locked_commit" ]]; then
      echo "missing locked commit for $repo_name" >&2
      exit 1
    fi
    git -C "$target_path" checkout --detach "$locked_commit"
  fi
done < "$manifest_path"
