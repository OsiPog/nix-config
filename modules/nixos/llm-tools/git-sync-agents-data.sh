#!/usr/bin/env bash
export PREK_ALLOW_NO_CONFIG=1
repo="$1"
cd "/mnt/agents-data/$repo"
git fetch --all
branch="$2"
set +e
  git checkout "$branch" --ignore-other-worktrees
  git pull --rebase origin "$branch"
  git push origin "$branch"
set -e
