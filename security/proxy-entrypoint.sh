#!/bin/sh
set -e

# Fix ownership on the host bind-mounted log directory.
# Bind mounts arrive as root:root; squid drops to the 'proxy' user and
# needs write access to /var/log/squid before it opens the log file.
mkdir -p /var/log/squid
chown proxy:proxy /var/log/squid
chmod 755 /var/log/squid  # traversable by host uid without elevation

# Daily log rotation in the background.
# After exec below, squid is PID 1. SIGUSR1 to PID 1 tells squid to close
# the current log, rename it to access.log.0 (then .1, .2 per logfile_rotate),
# and open a fresh access.log. Files older than 3 days are then removed.
(
    while true; do
        sleep 86400
        kill -USR1 1 2>/dev/null || true
        find /var/log/squid -name 'access.log.*' -mtime +3 -delete 2>/dev/null || true
    done
) &

exec squid -NYC -f /etc/squid/squid.conf
