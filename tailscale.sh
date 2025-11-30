#!/bin/bash
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -m

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# IPTables Engine Selection (MikroTik Fix AC2)
if [ "$IPTABLES_MODE" = "legacy" ]; then
    if [ -f "/sbin/iptables-legacy" ]; then
        echo "Switching to Legacy IPTables mode..."
        ln -sf /sbin/iptables-legacy /sbin/iptables
        ln -sf /sbin/ip6tables-legacy /sbin/ip6tables
    else
        echo "WARNING: iptables-legacy not found, using default."
    fi
fi

# Custom Pre-Start Command
if [[ -n "$PRE_START_COMMAND" ]]; then
    echo "Executing Pre-Start: $PRE_START_COMMAND"
    eval "$PRE_START_COMMAND"
fi

# Prepare run dirs
if [ ! -d "/var/run/sshd" ]; then
  mkdir -p /var/run/sshd
fi

# Set root password
echo "root:${PASSWORD}" | chpasswd

# Install routes
IFS=',' read -ra SUBNETS <<< "${ADVERTISE_ROUTES}"
for s in "${SUBNETS[@]}"; do
  ip route add "$s" via "${CONTAINER_GATEWAY}"
done

# Perform an update if set
if [[ ! -z "${UPDATE_TAILSCALE+x}" ]]; then
  /usr/local/bin/tailscale update --yes
fi

# Set login server for tailscale
if [[ -z "$LOGIN_SERVER" ]]; then
	LOGIN_SERVER=https://controlplane.tailscale.com
fi

if [[ -n "$STARTUP_SCRIPT" ]]; then
       bash "$STARTUP_SCRIPT" || exit $?
fi

# Start tailscaled and bring tailscale up
/usr/local/bin/tailscaled ${TAILSCALED_ARGS} &
until /usr/local/bin/tailscale up \
  --reset --authkey="${AUTH_KEY}" \
	--login-server "${LOGIN_SERVER}" \
	--advertise-routes="${ADVERTISE_ROUTES}" \
  ${TAILSCALE_ARGS}
do
    sleep 0.1
done
echo Tailscale started

# Start SSH
/usr/sbin/sshd -D

fg %1
