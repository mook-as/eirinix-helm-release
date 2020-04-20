#!/bin/sh

# This script generates the necessary configs for eirini-loggregator-bridge.

set -o errexit -o nounset -o xtrace

gomplate \
    --datasource namespace=env:NAMESPACE \
    --datasource endpoint=env:LOGGREGATOR_ENDPOINT \
    > /run/secrets/config/eirini-loggregator-bridge.yaml \
    <<EOF
namespace: {{ ds "namespace" }}
loggregator-endpoint: {{ ds "endpoint" }}
loggregator-ca-path: /run/secrets/loggregator-ca/certificate
loggregator-cert-path: /run/secrets/loggregator-cert/certificate
loggregator-key-path: /run/secrets/loggregator-cert/key
EOF

cat /run/secrets/config/eirini-loggregator-bridge.yaml
