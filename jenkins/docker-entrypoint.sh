#!/bin/bash
set -e
chmod 666 /var/run/docker.sock 2>/dev/null || true
exec gosu jenkins /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
