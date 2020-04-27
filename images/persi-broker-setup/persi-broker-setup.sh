#!/bin/sh

set -o errexit -o nounset -o pipefail

cat >/run/secrets/config/eirini-persi-broker.yml <<EOF
${SERVICE_CONFIG}
auth:
    username: admin
    password: $(cat /run/secrets/auth-password/password)
backend_host: 0.0.0.0
backend_port: 8999
namespace: ${NAMESPACE}
EOF
