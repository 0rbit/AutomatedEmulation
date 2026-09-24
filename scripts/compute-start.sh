#!/usr/bin/env bash
# Start Automated Emulation EC2 instances. Use --wait to block until running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=compute-common.sh
source "${SCRIPT_DIR}/compute-common.sh"

WAIT=0
if [[ "${1:-}" == "--wait" ]]; then
  WAIT=1
fi

require_aws

ids="$(lab_instance_ids)"
if [[ -z "${ids}" ]]; then
  echo "No lab EC2 instances found (VPC tag Name=operator_vpc)."
  exit 0
fi

echo "Current:"
print_compute_status

# shellcheck disable=SC2086
stopped="$(aws ec2 describe-instances \
  --region "${AWS_REGION_RESOLVED}" \
  --instance-ids ${ids} \
  --query 'Reservations[].Instances[?State.Name==`stopped`].InstanceId' \
  --output text | tr '\t' ' ' | awk 'NF')"

if [[ -z "${stopped}" ]]; then
  echo "No stopped instances to start."
  exit 0
fi

# shellcheck disable=SC2086
aws ec2 start-instances --region "${AWS_REGION_RESOLVED}" --instance-ids ${stopped} >/dev/null
echo "Start requested for: ${stopped}"

if [[ "${WAIT}" -eq 1 ]]; then
  # shellcheck disable=SC2086
  wait_for_instances running ${stopped}
  print_compute_status
fi
