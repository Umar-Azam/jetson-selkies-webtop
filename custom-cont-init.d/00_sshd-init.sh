#!/usr/bin/env bash

# This script runs at container start up.  It prepares the OpenSSH daemon
# for use by generating host keys (if necessary) and optionally setting a
# default password for the `abc` user.  The script is placed in
# `/custom-cont-init.d`, which LinuxServer's s6 init system executes before
# any services are started【382432676714424†L363-L370】.

set -e

echo "**** Preparing OpenSSH server ****"

# Generate SSH host keys only if they do not already exist.  Without
# host keys the SSH daemon refuses to start.
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# Ensure the 'abc' user has a known password.  If you plan to use SSH
# public key authentication exclusively, consider deleting or commenting
# this line and configuring authorized_keys in the persistent home
# directory (/home/abc/.ssh).
if [ -n "${SSH_DEFAULT_PASSWORD:-}" ]; then
    echo "abc:${SSH_DEFAULT_PASSWORD}" | chpasswd
fi

echo "**** OpenSSH preparation complete ****"