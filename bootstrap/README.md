# Debian 13 Proxmox template (VM 9000)

`create-debian-template-9000.sh` is a **one-time bootstrap script for the Proxmox node**, not an Ansible playbook and not something Terraform runs. It downloads Debian 13's `debian-13-generic-amd64.qcow2` cloud image, checks it against Debian's `SHA512SUMS`, installs and enables `qemu-guest-agent` inside the image, imports it into Proxmox, configures cloud-init and converts VM 9000 into a template. Terraform then clones that template for Vaultwarden.

## Prerequisites

- Root shell on the **Proxmox node that will host the template and VM**. VM ID **9000 must be unused**; the script refuses to modify an existing VM 9000.
- Storage `local-lvm` (or set `STORAGE`), a network bridge `vmbr0` (or set `BRIDGE`), DHCP on the VM network, and adequate free storage for the imported disk.
- Outbound HTTPS from the Proxmox node for the Debian image, checksums and guest package installation. Free space in `/var/tmp` for the downloaded image and temporary customization; set `TMPDIR` if another filesystem is more suitable.
- The **HomeLab public SSH key** stored on the Proxmox node as `/root/homelab-pubkey.pub` by default. This is a *public* key file, never the private key. The script fails if it is missing or empty.

On the Proxmox node, install the image customization tool and downloader if needed:

```sh
apt-get update
apt-get install -y wget libguestfs-tools
```

## Run once

From your local repository root, copy the script and the **public** key file to the Proxmox node (replace these example paths/hostnames with yours):

```sh
scp bootstrap/create-debian-template-9000.sh root@YOUR_PROXMOX_NODE:/root/
scp /path/to/homelab-pubkey.pub root@YOUR_PROXMOX_NODE:/root/homelab-pubkey.pub
ssh root@YOUR_PROXMOX_NODE
```

In the **Proxmox node's root shell**:

```sh
bash /root/create-debian-template-9000.sh
qm config 9000
```

The script sets 2 CPU cores, 2048 MiB RAM, `scsi0` on `local-lvm`, a cloud-init drive, a virtio NIC on `vmbr0`, DHCP, the guest-agent setting, the `catto` cloud-init user and the HomeLab SSH public key. Confirm VM 9000 is marked as a template, with the expected disk, cloud-init drive and key, before applying Terraform. Verify the guest agent is running on a booted clone; enabling it on a template alone cannot verify a guest is online.

## Changing defaults

Set environment variables **on the Proxmox node when running the script** if your setup differs, for example:

```sh
STORAGE=fast-lvm BRIDGE=vmbr1 TEMPLATE_USER=catto SSH_PUBLIC_KEY_FILE=/root/homelab-pubkey.pub bash /root/create-debian-template-9000.sh
```

`TMPDIR` changes where the temporary download directory is created. The VM ID and Debian image URL are fixed in the script: review and edit the script deliberately if you need a different ID or image. Debian's `trixie/latest` image changes over time; record the image build/date for reproducibility. The SHA512 checksum comes from the same HTTPS origin as the image and is **not** an independent signature verification.

The script cleans up its temporary download but **does not destroy a partially created VM** if a `qm` command fails. Inspect VM 9000 and any allocated disks before deciding whether to clean up and retry; do not blindly rerun or delete an existing VM.

## Use the template with Terraform

Set `debian_template_vm_id = 9000`, `proxmox_datastore_id` to the storage used above, and `vm_admin_user` to the template user (`catto` by default) in your local `terraform/terraform.tfvars`. Set `shared_ssh_public_key` to the HomeLab *public* key, and `vaultwarden_ssh_public_key` to Vaultwarden's separate *public* key. Terraform does **not** copy `shared_ssh_public_key` to the template: the script configures the template key from the file on the Proxmox node. Terraform replaces that cloud-init key setting on the **Vaultwarden clone** with `vaultwarden_ssh_public_key`; configure your SSH client and `ansible/vaultwarden/inventory.ini` accordingly. Never put a private SSH key in Terraform, on the template, or in this repository.

For the rest of the VM deployment, follow [`docs/setup.md`](../docs/setup.md) and [`ansible/vaultwarden/README.md`](../ansible/vaultwarden/README.md).
