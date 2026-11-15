#!/usr/bin/env bash
# Legt alle Repositories fuer die Juice-Shop-Pipeline in JFrog an.
# Naming convention: <projekt>-<technologie>-<reifegrad>-<typ>
set -euo pipefail

JFROG_URL="${JFROG_URL:-https://trialshcdre.jfrog.io}"
: "${JFROG_TOKEN:?Bitte zuerst JFROG_TOKEN setzen}"

create_repo() {
  local key="$1" json="$2" code
  printf '%-28s ' "$key"
  code=$(curl -sS -o /tmp/jfrog_resp.txt -w '%{http_code}' -X PUT \
    -H "Authorization: Bearer ${JFROG_TOKEN}" \
    -H "Content-Type: application/json" \
    "${JFROG_URL}/artifactory/api/repositories/${key}" \
    -d "$json")
  if [[ "$code" == "200" ]]; then
    echo "OK"
  else
    echo "FEHLER ($code): $(cat /tmp/jfrog_resp.txt)"
  fi
}

echo "Erstelle Repositories auf ${JFROG_URL} ..."

# ---------- npm ----------
create_repo juice-npm-remote '{
  "rclass": "remote", "packageType": "npm",
  "url": "https://registry.npmjs.org",
  "xrayIndex": true,
  "description": "Proxy/Cache fuer npmjs.org"
}'

create_repo juice-npm-dev-local '{
  "rclass": "local", "packageType": "npm",
  "xrayIndex": true,
  "description": "Interne npm-Pakete (dev)"
}'

create_repo juice-npm-virtual '{
  "rclass": "virtual", "packageType": "npm",
  "repositories": ["juice-npm-dev-local", "juice-npm-remote"],
  "defaultDeploymentRepo": "juice-npm-dev-local",
  "description": "Einziger Zugangspunkt fuer npm im CI"
}'

# ---------- Docker ----------
create_repo juice-docker-hub-remote '{
  "rclass": "remote", "packageType": "docker",
  "url": "https://registry-1.docker.io/",
  "enableTokenAuthentication": true,
  "xrayIndex": true,
  "description": "Proxy/Cache fuer Docker Hub (node:24)"
}'

create_repo juice-docker-gcr-remote '{
  "rclass": "remote", "packageType": "docker",
  "url": "https://gcr.io",
  "enableTokenAuthentication": true,
  "xrayIndex": true,
  "description": "Proxy/Cache fuer gcr.io (distroless)"
}'

create_repo juice-docker-dev-local '{
  "rclass": "local", "packageType": "docker",
  "dockerApiVersion": "V2",
  "xrayIndex": true,
  "description": "Images aus dem CI (noch nicht freigegeben)"
}'

create_repo juice-docker-prod-local '{
  "rclass": "local", "packageType": "docker",
  "dockerApiVersion": "V2",
  "xrayIndex": true,
  "description": "Freigegebene Images (nach bestandenem Security-Gate)"
}'

create_repo juice-docker-virtual '{
  "rclass": "virtual", "packageType": "docker",
  "repositories": ["juice-docker-dev-local", "juice-docker-prod-local", "juice-docker-hub-remote", "juice-docker-gcr-remote"],
  "defaultDeploymentRepo": "juice-docker-dev-local",
  "description": "Einziger Zugangspunkt fuer Docker im CI"
}'

echo "Fertig."
