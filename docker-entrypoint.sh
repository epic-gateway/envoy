#!/usr/bin/env sh
set -e

# If this is a TrueIngress LB, then set up routes to send traffic by
# default through net1 (the TrueIngress/Multus interface) with pod and
# internal service network traffic going through eth0, the k8s
# interface. TrueIngress is the default, so it needs to be explicitly
# disabled.
if [ "$TRUEINGRESS" != "disabled" ] ; then
    # Get the pod CIDR from Calico
    POD_CIDR=$(calicoctl get ipPool default-ipv4-ippool --output=go-template="{{(index . 0).Spec.CIDR}}")
    # Set up a route to send pod traffic to the k8s/default interface
    ip route add "$POD_CIDR" dev eth0

    # If the SERVICE_CIDR env var is set, add a route to send internal
    # service traffic to the k8s/default interface
    if [ "X$SERVICE_CIDR" != "X" ] ; then
        ip route add "$SERVICE_CIDR" dev eth0
    fi

    # set up routes to send traffic by default through net1
    ip route delete 0.0.0.0/0
    ip route add 0.0.0.0/0 dev net1
fi

loglevel="${loglevel:-}"

# if the first argument look like a parameter (i.e. start with '-'), run Envoy
if [ "${1#-}" != "$1" ]; then
        set -- envoy "$@"
fi

if [ "$1" = 'envoy' ]; then
        # set the log level if the $loglevel variable is set
        if [ -n "$loglevel" ]; then
                set -- "$@" --log-level "$loglevel"
        fi
fi

if [ "$ENVOY_UID" != "0" ]; then
    if [ -n "$ENVOY_UID" ]; then
        usermod -u "$ENVOY_UID" envoy
    fi
    if [ -n "$ENVOY_GID" ]; then
        groupmod -g "$ENVOY_GID" envoy
    fi
    # Ensure the envoy user is able to write to container logs
    chown envoy:envoy /dev/stdout /dev/stderr
    su-exec envoy "${@}"
else
    exec "${@}"
fi
