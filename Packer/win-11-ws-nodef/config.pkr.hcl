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
  type = string
  default = "../../seclab.kdbx"
}

variable "ca_cert_path" {
  type = string
  default = "../../pki/root_ca.crt"
}

variable "keepass_password" {
  type = string
  sensitive = true
}

data "keepass-credentials" "kpxc" {
  keepass_file = "${var.keepass_database}"
  keepass_password = "${var.keepass_password}"
}

variable "hostname" {
  type    = string
  default = "win11-ws-nodef"
}

locals {
  username          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_windows-UserName"]
  password          = data.keepass-credentials.kpxc.map["/Passwords/Seclab/seclab_windows-Password"]
  proxmox_api_id    = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-UserName"]
  proxmox_api_token = data.keepass-credentials.kpxc.map["/Passwords/Seclab/proxmox_api-Password"]
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

source "proxmox-iso" "seclab-win-ws" {
  proxmox_url  = "https://${var.proxmox_api_host}:8006/api2/json"
  node         = "${var.proxmox_node}"
  username     = "${local.proxmox_api_id}"
  token        = "${local.proxmox_api_token}"
  bios         = "ovmf"
  boot_iso {
    type         = "sata"
    iso_file     = "${var.iso_storage}:iso/win11-25H2.iso"
    iso_checksum = "sha256:a61adeab895ef5a4db436e0a7011c92a2ff17bb0357f58b13bbc4062e535e7b9"
    unmount      = true
  }
  /*skip_export             = true*/
  communicator             = "ssh"
  ssh_username             = "${local.username}"
  ssh_password             = "${local.password}"
  ssh_timeout              = "60m"
  qemu_agent               = true
  cores                    = 4
  memory                   = 8192
  vm_name                  = "seclab-win11-ws"
  template_description     = "Base Seclab Windows 11 Workstation"
  os                       = "win11"
  insecure_skip_tls_verify = true
  machine                  = "pc-q35-9.0"
  cpu_type                 = "x86-64-v2-AES"
  boot                     = "order=sata0;virtio0"
  boot_wait                = "5s"
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
    iso_file     = "${var.iso_storage}:iso/Autounattend-win-11-ws-nodef.iso"
    iso_checksum = "sha256:a3e9f22d974b9f0daa1c6a565f86cee4d61371f4a69f59cdcc9a076c2e27054a"
  }
  
  additional_iso_files {
    index        = 2
    type         = "sata"
    iso_file     = "${var.iso_storage}:iso/virtio-win.iso"
    iso_checksum = "sha256:e14cf2b94492c3e925f0070ba7fdfedeb2048c91eea9c5a5afb30232a3976331"
  }

  network_adapters {
    bridge = "${var.network_adapter}"
  }

  disks {
    type         = "virtio"
    disk_size    = "80G"
    storage_pool = "${var.storage_pool}"
    format       = "raw"
  }
  scsi_controller = "virtio-scsi-single"

}

build {
  sources = ["sources.proxmox-iso.seclab-win-ws"]
  provisioner "file" {
    source = "${var.ca_cert_path}"
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
