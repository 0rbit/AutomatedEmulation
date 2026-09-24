#!/usr/bin/env bash
# Show status of Automated Emulation EC2 instances (BAS + Windows).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=compute-common.sh
source "${SCRIPT_DIR}/compute-common.sh"

require_aws
print_compute_status
