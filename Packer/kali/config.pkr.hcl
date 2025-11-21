packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
    keepass = {
      version = ">= 0.3.0"
      source  = "github.com/chunqi/keepass"
    }
  }
}

variable "keepass_database" {
  type = string
  default = "../../seclab.kdbx"
}

variable "keepass_password" {
  type = string
  sensitive = true
}

variable "ca_cert_path" {
  type = string
  default = "../../pki/ca.crt"
}

data "keepass-credentials" "kpxc" {
  keepass_file = "${var.keepass_database}"
  keepass_password = "${var.keepass_password}"
}

variable "hostname" {
  type    = string
  default = "kali"
}

variable "proxmox_api_host" {
  type    = string
  default = "proxmox"
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "storage_pool" {
  type    = string
  default = "main"
}

variable "iso_storage" {
  type    = string
  default = "store"
}

variable "network_adapter" {
  type    = string
  default = "vmbr1"
}

locals {
  username          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_user-UserName"]
  password          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_user-Password"]
  proxmox_api_id    = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-UserName"]
  proxmox_api_token = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-Password"]
}


source "proxmox-iso" "seclab-kali" {
  proxmox_url = "https://${var.proxmox_api_host}:8006/api2/json"
  node        = "${var.proxmox_node}"
  username    = "${local.proxmox_api_id}"
  token       = "${local.proxmox_api_token}"
  boot_iso {
    type         = "ide"
    iso_file     = "${var.iso_storage}:iso/kali-linux-2025.3-installer-amd64.iso"
    iso_checksum = "sha256:fcf1999799f6642b7d6c6bd79bc1e516be7340b7203fe86c6be3ac21f693f42a"
    unmount      = true

  }
  ssh_username             = "${local.username}"
  ssh_password             = "${local.password}"
  ssh_handshake_attempts   = 100
  ssh_timeout              = "4h"
  http_directory           = "http"
  cores                    = 4
  memory                   = 8192
  vm_name                  = "seclab-kali"
  qemu_agent               = true
  template_description     = "Kali"
  insecure_skip_tls_verify = true
  machine                  = "pc-q35-9.0"
  cpu_type                 = "x86-64-v2-AES"


  network_adapters {
    bridge = "${var.network_adapter}"
  }

  disks {
    type         = "virtio"
    disk_size    = "50G"
    storage_pool = "${var.storage_pool}"
    format       = "raw"
  }
  boot_wait = "10s"
  boot_command = [
    "<esc><wait>",
    "/install.amd/vmlinuz noapic ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kali.preseed ",
    "hostname=${var.hostname} ",
    "auto=true ",
    "interface=auto ",
    "domain=vm ",
    "initrd=/install.amd/initrd.gz -- <enter>"
  ]
}

build {
  sources = ["sources.proxmox-iso.seclab-kali"]
  provisioner "file" {
    source = "${var.ca_cert_path}"
    destination = "/tmp/ca.crt"
  }
  provisioner "shell" {
    inline = [
      "sudo cp /tmp/ca.crt /usr/local/share/ca-certificates",
      "sudo rm /tmp/ca.crt",
      "sudo update-ca-certificates"
    ]
  }
}
