#!/bin/sh
# link-hints opener: run by launchd (inetd-style) for each connection on the
# Unix socket that remote hosts reach through `RemoteForward`. Reads one URL
# from stdin and opens it in the local browser. Only http(s) URLs are accepted.
IFS= read -r url || [ -n "$url" ] || exit 0
case "$url" in
  http://*|https://*) ;;
  *) exit 0 ;;
esac
case "$url" in
  *[[:space:][:cntrl:]]*) exit 0 ;;
esac
exec /usr/bin/open "$url"
