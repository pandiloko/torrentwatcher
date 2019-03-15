#!/bin/bash
set -x
content=$(find "/opt" -maxdepth 0 -type d -empty 2>/dev/null)
[ -n "$content" ] && sudo cp -rfu /tmp/opt / && sudo chown -R watcher:watcher /opt
exec "$@"
