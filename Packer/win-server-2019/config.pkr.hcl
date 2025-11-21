packer {
  required_plugins {
    proxmox = {
      version = "= 1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
    keepass = {
      version = ">= 0.3.0"
      source  = "github.com/chunqi/keepass"
    }
  }
}

variable "keepass_database" {
  type    = string
  default = "../../seclab.kdbx"
}

variable "ca_cert_path" {
  type    = string
  default = "../../pki/ca.crt"
}

variable "keepass_password" {
  type      = string
  sensitive = true
}

data "keepass-credentials" "kpxc" {
  keepass_file     = "${var.keepass_database}"
  keepass_password = "${var.keepass_password}"
}

variable "hostname" {
  type    = string
  default = "win-server-2019"
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
  default = "vmbr2"
}

locals {
  username          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_windows-UserName"]
  password          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_windows-Password"]
  proxmox_api_id    = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-UserName"]
  proxmox_api_token = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-Password"]
}

source "proxmox-iso" "seclab-win-server" {
  proxmox_url = "https://${var.proxmox_api_host}:8006/api2/json"
  node        = "${var.proxmox_node}"
  username    = "${local.proxmox_api_id}"
  token       = "${local.proxmox_api_token}"
  boot_iso {
    type         = "sata"
    iso_file     = "${var.iso_storage}:iso/winserver-2019.iso"
    iso_checksum = "sha256:6dae072e7f78f4ccab74a45341de0d6e2d45c39be25f1f5920a2ab4f51d7bcbb"
    unmount      = true
  }
  insecure_skip_tls_verify = true
  communicator             = "ssh"
  ssh_username             = "${local.username}"
  ssh_password             = "${local.password}"
  ssh_timeout              = "30m"
  qemu_agent               = true
  cores                    = 2
  memory                   = 4096
  vm_name                  = "seclab-win-server-19"
  template_description     = "Base Seclab Windows Server"
  os                       = "win10"
  machine                  = "pc-q35-9.0"
  cpu_type                 = "x86-64-v2-AES"
  boot                     = "order=sata0;virtio0"
  boot_wait                = "30s"
  boot_command             = [
    "<space><space><space><space><space><space>",
    "<space><space><space><space><space><space>",
    "<space><space><space><space><space><space>",
    "<space><space><space><space><space><space>",
    "<space><space><space><space><space><space>",
    "<wait60s><enter>"
  ]

  efi_config {
    efi_storage_pool  = "${var.storage_pool}"
    efi_type          = "4m"
    pre_enrolled_keys = true
  }
  tpm_config {
    tpm_storage_pool = "${var.storage_pool}"
    tpm_version      = "v2.0"
  }

  additional_iso_files {
    index        = 1
    type         = "sata"
    iso_file     = "${var.iso_storage}:iso/Autounattend-win-server-2019.iso"
    iso_checksum = "sha256:e5bed2561773339e9a44a0cda8e00fc6d3ab81080d815ea152eb61bb51458110"
    unmount      = true
  }

  additional_iso_files {
    index        = 2
    type         = "sata"
    iso_file     = "${var.iso_storage}:iso/virtio-win.iso"
    iso_checksum = "sha256:e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331"
    unmount      = true
  }


  network_adapters {
    bridge = "${var.network_adapter}"
  }

  disks {
    type         = "virtio"
    disk_size    = "50G"
    storage_pool = "${var.storage_pool}"
    format       = "raw"
  }
  scsi_controller = "virtio-scsi-pci"
}


build {
  sources = ["sources.proxmox-iso.seclab-win-server"]
  provisioner "file" {
    source      = "${var.ca_cert_path}"
    destination = "C:/Windows/Temp/ca.crt"
  }
  provisioner "windows-shell" {
    inline = [
      "powershell.exe -c Import-Certificate -FilePath C:\\Windows\\Temp\\ca.crt -CertStore Cert:\\LocalMachine\\Root",
      "powershell.exe -c Rename-Computer ${var.hostname}",
      "ipconfig"
    ]
  }
}
