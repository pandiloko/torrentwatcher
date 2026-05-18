#!/usr/bin/env bash
# Convenience wrapper: run the installed app script from the repository root.
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${_repo_root}/app/torrentwatcher.sh" "$@"
