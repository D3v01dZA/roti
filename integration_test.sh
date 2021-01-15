#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-f] -p param_value arg1 [arg2...]

Run integration tests

Available options:

-h, --help      Print this help and exit
-c, --cleanup   Cleanup the test containers
-v, --verbose   Print script debug info
-f, --flag      Some flag description
-p, --param     Some param description
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  set +Eeuo pipefail
  docker kill one > /dev/null
  docker rm one > /dev/null
  docker kill two > /dev/null
  docker rm two > /dev/null
  docker kill thr > /dev/null
  docker rm thr > /dev/null
  docker network rm integration_test > /dev/null
}


setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  run_cleanup=0

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -c | --cleanup) run_cleanup=1 ;; # example flag
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  return 0
}

parse_params "$@"
setup_colors

if [[ "${run_cleanup}" -eq 1 ]]; then
  cleanup
  msg "Cleanup done"
  exit 0
fi

msg "Building"
cargo build
docker build . -t roti:latest > /dev/null

msg "Starting containers"
docker network create --subnet=172.18.0.0/16 integration_test > /dev/null
docker run --name one --net integration_test --ip 172.18.0.241 --detach roti:latest > /dev/null
docker run --name two --net integration_test --ip 172.18.0.242 --detach roti:latest > /dev/null
docker run --name thr --net integration_test --ip 172.18.0.243 --detach roti:latest > /dev/null

msg "Curling"
curl -f --write-out "\n%{http_code}\n" 172.18.0.241:8080/peer
curl -f --write-out "\n%{http_code}\n" 172.18.0.241:8080/peer -X POST -H "Content-Type: application/json" -d '{"address": "addr"}'
curl -f --write-out "\n%{http_code}\n" 172.18.0.241:8080/peer

curl -f --write-out "\n%{http_code}\n" 172.18.0.242:8080/peer
curl -f --write-out "\n%{http_code}\n" 172.18.0.242:8080/peer -X POST -H "Content-Type: application/json" -d '{"address": "addr"}'
curl -f --write-out "\n%{http_code}\n" 172.18.0.242:8080/peer

curl -f --write-out "\n%{http_code}\n" 172.18.0.243:8080/peer
curl -f --write-out "\n%{http_code}\n" 172.18.0.243:8080/peer -X POST -H "Content-Type: application/json" -d '{"address": "addr"}'
curl -f --write-out "\n%{http_code}\n" 172.18.0.243:8080/peer
