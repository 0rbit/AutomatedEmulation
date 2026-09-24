#!/usr/bin/env bash
# Show status of lab EC2 instances (bas, win1, ubuntu1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=compute-common.sh
source "${SCRIPT_DIR}/compute-common.sh"

require_aws
print_compute_status
