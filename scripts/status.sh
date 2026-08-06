#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$workspace_root/repositories.tsv"

echo "workspace"
git -C "$workspace_root" status --short --branch

while IFS=$'\t' read -r repo_name repo_path _repo_url _default_ref repo_role; do
  [[ -z "$repo_name" || "$repo_name" == \#* ]] && continue
  target_path="$workspace_root/$repo_path"
  echo
  echo "$repo_name [$repo_role]"
  if [[ ! -d "$target_path/.git" ]]; then
    echo "not cloned: $repo_path"
    continue
  fi
  git -C "$target_path" status --short --branch
done < "$manifest_path"
