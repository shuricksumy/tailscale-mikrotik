#!/bin/bash
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -m

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# --- 1. Total Legacy Locking (Strict Mapping for MikroTik) ---
if [ "$IPTABLES_MODE" = "legacy" ]; then
    # Direct path to the master legacy binary
    B="/usr/sbin/xtables-legacy-multi"
    
    if [ -f "$B" ]; then
        echo "Locking all networking utilities to Legacy engine..."
        
        # This list covers every binary from your 'ls' output to prevent 'Invalid Argument' errors
        for cmd in \
            iptables iptables-save iptables-restore iptables-translate iptables-restore-translate \
            ip6tables ip6tables-save ip6tables-restore ip6tables-translate ip6tables-restore-translate \
            arptables arptables-save arptables-restore arptables-translate \
            ebtables ebtables-save ebtables-restore ebtables-translate \
            xtables-monitor
        do
            # Force link (ln -sf) replaces existing nft links with the legacy pointer
            ln -sf "$B" /usr/sbin/$cmd
            ln -sf "$B" /sbin/$cmd 2>/dev/null || true
        done
        
        echo "Verification: $(iptables --version)"
    else
        echo "CRITICAL: $B not found! Networking will likely fail on this kernel."
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
if [[ "$UPDATE_TAILSCALE" = "Y"  ]]; then
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
