#!/bin/bash
set -x
content=$(find "/opt" -maxdepth 0 -type d -empty 2>/dev/null)
[ -n "$content" ] && sudo cp -rfu /tmp/opt / && sudo chown -R watcher:watcher /opt
if [ -z $CUSTOM_GROUP_ID ] || [ -z $CUSTOM_USER_ID ];then
	[ -z $CUSTOM_USER_ID ]  && sudo usermod -u $CUSTOM_USER_ID watcher
	[ -z $CUSTOM_GROUP_ID ] && sudo groupmod -g $CUSTOM_GROUP_ID watcher
	chown -R watcher:watcher /tmp/opt /opt
fi
exec "$@"
