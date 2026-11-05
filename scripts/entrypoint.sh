#!/bin/sh
# dsh listens on loopback so that `kubectl port-forward` and in-container clients reach it.
# A TCP relay publishes it on one concrete address (the pod IP from DSH_HOST, or the
# container's first address), because dsh rejects wildcard binds.
set -eu
port="${DSH_PORT:-3080}"
host="${DSH_HOST:-$(hostname -i | cut -d' ' -f1)}"
case "$host" in
	127.*|::1|localhost) ;;
	*) node /usr/local/lib/dsh-relay.mjs "$host" "$port" "$port" & ;;
esac
exec dsh --profile web --no-open --host 127.0.0.1 --port "$port" "$@"
