#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$workspace_root/repositories.tsv"

git -C "$workspace_root" diff --check
bash -n "$workspace_root"/scripts/*.sh

while IFS=$'\t' read -r repo_name repo_path _repo_url _default_ref repo_role; do
  [[ -z "$repo_name" || "$repo_name" == \#* ]] && continue
  [[ "$repo_role" != "product" ]] && continue
  target_path="$workspace_root/$repo_path"
  if [[ ! -d "$target_path/.git" ]]; then
    echo "skipped (not cloned): $repo_name"
    continue
  fi

  echo "checking: $repo_name"
  git -C "$target_path" diff --check
  if [[ -x "$target_path/scripts/check.sh" ]]; then
    "$target_path/scripts/check.sh"
  else
    echo "no repository-specific check command yet"
  fi
done < "$manifest_path"
