#!/usr/bin/env bash
set -euo pipefail

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$workspace_root/repositories.tsv"
lock_path="$workspace_root/repositories.lock"
temporary_lock="$(mktemp "${TMPDIR:-/tmp}/ipchronicle-repositories.XXXXXX")"
trap 'rm -f "$temporary_lock"' EXIT

printf '# name\tcommit\n' > "$temporary_lock"

while IFS=$'\t' read -r repo_name repo_path _repo_url _default_ref _repo_role; do
  [[ -z "$repo_name" || "$repo_name" == \#* ]] && continue
  target_path="$workspace_root/$repo_path"
  if [[ ! -d "$target_path/.git" ]]; then
    echo "repository is not cloned: $repo_name ($repo_path)" >&2
    exit 1
  fi
  repo_commit="$(git -C "$target_path" rev-parse HEAD)"
  printf '%s\t%s\n' "$repo_name" "$repo_commit" >> "$temporary_lock"
done < "$manifest_path"

mv "$temporary_lock" "$lock_path"
trap - EXIT
echo "updated: $lock_path"
