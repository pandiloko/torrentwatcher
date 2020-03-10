#!/bin/bash
set -x
content=$(find "/opt" -maxdepth 0 -type d -empty 2>/dev/null)
[ -n "$content" ] && sudo cp -rfu /tmp/opt / && sudo chown -R watcher:watcher /opt
if [ -n $CUSTOM_GROUP_ID ] || [ -n $CUSTOM_USER_ID ];then
	[ -n $CUSTOM_USER_ID ]  && sudo usermod -u $CUSTOM_USER_ID watcher
	[ -n $CUSTOM_GROUP_ID ] && sudo groupmod -g $CUSTOM_GROUP_ID watcher
	sudo chown -R watcher:watcher /tmp/opt /opt
fi
exec "$@"
