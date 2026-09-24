#!/usr/bin/env bash
# Stop Automated Emulation EC2 instances. Use --wait to block until stopped.

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

echo "Stopping:"
print_compute_status

# shellcheck disable=SC2086
running="$(aws ec2 describe-instances \
  --region "${AWS_REGION_RESOLVED}" \
  --instance-ids ${ids} \
  --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' \
  --output text | tr '\t' ' ' | awk 'NF')"

if [[ -z "${running}" ]]; then
  echo "No running instances to stop."
  exit 0
fi

# shellcheck disable=SC2086
aws ec2 stop-instances --region "${AWS_REGION_RESOLVED}" --instance-ids ${running} >/dev/null
echo "Stop requested for: ${running}"

if [[ "${WAIT}" -eq 1 ]]; then
  # shellcheck disable=SC2086
  wait_for_instances stopped ${running}
  print_compute_status
fi
