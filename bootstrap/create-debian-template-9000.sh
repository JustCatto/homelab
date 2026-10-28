#!/usr/bin/env bash
# Run on the target Proxmox node as root. This creates VM template 9000 once.
set -euo pipefail

VM_ID=9000
IMAGE_NAME=debian-13-generic-amd64.qcow2
IMAGE_BASE_URL=https://cloud.debian.org/images/cloud/trixie/latest
STORAGE=${STORAGE:-local-lvm}
BRIDGE=${BRIDGE:-vmbr0}
TEMPLATE_USER=${TEMPLATE_USER:-catto}
# HomeLab public key stored on the Proxmox node; clones may override it.
SSH_PUBLIC_KEY_FILE=${SSH_PUBLIC_KEY_FILE:-/root/homelab-pubkey.pub}

if (( EUID != 0 )); then
  echo 'Run this script as root on the Proxmox node.' >&2
  exit 1
fi
for tool in qm wget virt-customize sha512sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool; see docs/setup.md for prerequisites." >&2
    exit 1
  fi
done
if qm config "$VM_ID" >/dev/null 2>&1; then
  echo "VM ID $VM_ID already exists; refusing to modify it." >&2
  exit 1
fi
if [[ ! -s "$SSH_PUBLIC_KEY_FILE" ]]; then
  echo "HomeLab SSH public key file missing or empty: $SSH_PUBLIC_KEY_FILE" >&2
  exit 1
fi
if grep -q 'PRIVATE KEY' "$SSH_PUBLIC_KEY_FILE"; then
  echo 'SSH_PUBLIC_KEY_FILE must contain a public key, never a private key.' >&2
  exit 1
fi

workdir=$(mktemp -d -p "${TMPDIR:-/var/tmp}" debian-13-template.XXXXXXXX)
trap 'rm -rf -- "$workdir"' EXIT

wget -O "$workdir/$IMAGE_NAME" "$IMAGE_BASE_URL/$IMAGE_NAME"
wget -O "$workdir/SHA512SUMS" "$IMAGE_BASE_URL/SHA512SUMS"
(cd "$workdir" && sha512sum -c SHA512SUMS --ignore-missing)

# Proxmox can query guest IPs only after the agent is installed and running.
virt-customize -a "$workdir/$IMAGE_NAME" \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent'

qm create "$VM_ID" --name debian-13-template --memory 2048 --cores 2 --net0 "virtio,bridge=$BRIDGE"
qm set "$VM_ID" --scsi0 "$STORAGE:0,import-from=$workdir/$IMAGE_NAME"
qm set "$VM_ID" --ide2 "$STORAGE:cloudinit"
qm set "$VM_ID" --boot order=scsi0
qm set "$VM_ID" --scsihw virtio-scsi-pci
qm set "$VM_ID" --serial0 socket --vga serial0
qm set "$VM_ID" --ipconfig0 ip=dhcp
qm set "$VM_ID" --agent enabled=1
qm set "$VM_ID" --ciuser "$TEMPLATE_USER"

# Template-level HomeLab key. The Vaultwarden clone sets its own cloud-init key.
qm set "$VM_ID" --sshkeys "$SSH_PUBLIC_KEY_FILE"

qm template "$VM_ID"
echo "Created Debian 13 template $VM_ID on $STORAGE with user $TEMPLATE_USER."
