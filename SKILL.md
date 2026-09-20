---
name: virtualbox-control
description: "Control VirtualBox VMs on Windows: open GUI, start/stop VMs, and run commands inside guests. Use when the user asks to open VirtualBox, launch/shut down a VM, check VM status, or execute commands inside a virtual machine. Prefer SSH over guestcontrol when Guest Additions is not installed."
---

# VirtualBox VM Control

## Overview

Manage VirtualBox virtual machines end-to-end from the command line. Three ways to run commands inside a guest, in order of preference:

1. **SSH** (preferred) — works once openssh-server is installed in the guest
2. **guestcontrol** — only works if Guest Additions is installed and running
3. **keyboardputscancode** — last resort, unreliable for long input

## Step 0 — Detect VirtualBox Installation Path

**Check cache first, only detect on first use.**

```powershell
$cacheFile = "$PSScriptRoot\.vbm_path"

# 1. Read cache if exists
if (Test-Path $cacheFile) {
    $VBM = (Get-Content $cacheFile -Raw).Trim()  # Trim removes trailing newline from file
    if (Test-Path $VBM) {
        Write-Host "Using cached VBoxManage: $VBM"
    } else {
        $VBM = $null  # cached path no longer valid, re-detect
    }
}

# 2. Detect if no valid cache
if (-not $VBM) {
    Write-Host "First run: detecting VirtualBox path..."

    # Check common installation paths
    $VBM = @(
        "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
        "C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe",
        "$env:LOCALAPPDATA\Programs\Oracle\VirtualBox\VBoxManage.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    # Fallback: search PATH
    if (-not $VBM) {
        $VBM = (Get-Command VBoxManage.exe -ErrorAction SilentlyContinue).Source
    }

    # Save to cache for next time
    if ($VBM) {
        $VBM | Out-File $cacheFile -Encoding utf8
        Write-Host "Found VBoxManage at: $VBM (cached)"
    } else {
        Write-Host "ERROR: VBoxManage.exe not found. Please install VirtualBox first."
        exit 1
    }
}
```

**Behavior:**
- First run on a new machine: detects path and saves to `.vbm_path` cache
- Subsequent runs: reads cache and skips detection (fast)
- If cached path stops working (e.g. VirtualBox reinstalled), re-detects automatically

## Step 1 — List and Start VMs

```powershell
& $VBM list vms          # registered VMs
& $VBM list runningvms   # running ones
```

Start in GUI mode (user can see the console):
```powershell
& $VBM startvm "VM_NAME" --type gui
```

Start headless (no window, faster):
```powershell
& $VBM startvm "VM_NAME" --type headless
```

Wait 15-30 seconds for the guest to finish booting.

## Step 2 — Run Commands Inside the Guest (SSH — preferred)

**SSH is the most reliable way to run commands inside a guest.** Use this whenever possible.

### Prerequisites
- Guest must have `openssh-server` installed and running
- Need guest username and password
- Need to know the guest IP (check from the guest console or via `ip a`)

### First-time SSH setup (from the guest console)

If openssh-server is not installed, the user needs to install it from the VM console first:

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Execute commands via SSH from Windows host

```powershell
# Run a single command
ssh -o StrictHostKeyChecking=no txl@192.168.5.3 "hostname"

# Run sudo command (will prompt for password)
ssh -o StrictHostKeyChecking=no txl@192.168.5.3 "sudo apt update"
```

**Note:** Windows OpenSSH does not support piping passwords via stdin. If you need non-interactive sudo, either:
- Ask the user to run the command manually in their SSH client (e.g. MobaXterm, PuTTY)
- Or set up SSH key authentication

### Using MobaXterm for interactive work

When the user has MobaXterm (or another SSH client) open and connected:
- Give the user short, copy-pasteable commands to run in their SSH window
- Break long commands into small steps so the user can paste easily
- The user can copy-paste from the chat directly into their SSH terminal

### Find the guest IP

From the host, you can scan the bridged network:
```powershell
# Check host IP first
ipconfig | Select-String "IPv4"
# Then scan common subnet
1..254 | ForEach-Object { Test-NetConnection "192.168.5.$_" -Port 22 -WarningAction SilentlyContinue | Where-Object TcpTestSucceeded }
```

## Step 3 — Run Commands via guestcontrol (if Guest Additions installed)

Works when Guest Additions is installed AND running inside the guest.

**Critical syntax note:** After `--`, the first item is `argv[0]` (the program name), not the first argument. You must include it or the command fails silently.

```powershell
# Run a bash command (correct syntax)
& $VBM guestcontrol "VM_NAME" run `
  --exe /bin/bash --username txl --password newland `
  -- bash -c "uname -a && df -h /"

# Simple command with arguments
& $VBM guestcontrol "VM_NAME" run `
  --exe /bin/ls --username txl --password newland `
  -- ls -l /home

# Run a single executable directly (no args needed)
& $VBM guestcontrol "VM_NAME" run `
  --exe /bin/hostname --username txl --password newland
```

**Common pitfalls:**
- If you omit the program name after `--`, the first argument becomes argv[0] and the command fails
- `--exe` points to the executable path, `--` args include argv[0] first
- If it fails with "guest execution service is not ready": Guest Additions is not installed. Use SSH instead (Step 2).

## Step 4 — keyboardputscancode (last resort — unreliable)

Use ONLY when SSH and guestcontrol are both unavailable.

```powershell
# Press Enter (make code 1C, release F0 1C)
& $VBM controlvm "VM_NAME" keyboardputscancode "1C F0 1C"
```

**Known issues (VirtualBox 6.1):**
- Release scancodes (`F0 + make`) are often unreliable — keys get stuck and auto-repeat
- Typing long commands this way is error-prone
- Use this only for simple single-key input (Enter, Tab, etc.)

## Step 5 — Stop the VM

```powershell
# Graceful shutdown (ACPI)
& $VBM controlvm "VM_NAME" acpipowerbutton

# Force power off
& $VBM controlvm "VM_NAME" poweroff

# Save state (freeze and resume)
& $VBM controlvm "VM_NAME" savestate
```

## Ubuntu 18.04 (Bionic) Notes

Ubuntu 18.04 is EOL. The default apt sources will fail. Use Aliyun mirror:

```bash
# Replace sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse" | sudo tee /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list
sudo apt update
```

**Do NOT use:**
- `old-releases.ubuntu.com` — 404s on bionic
- `gb.mirrors.tuna.tsinghua.edu.cn` — DNS resolution fails
- `ubuntu-old-releases` path on tuna — 404

## Installing Xfce GUI (if needed)

```bash
sudo apt install -y xfce4 xfce4-goodies
sudo apt install -y virtualbox-guest-x11
# For the kernel module:
sudo apt install -y gcc dkms virtualbox-guest-dkms
# Then start:
startxfce4
```

## Quick Reference

### Basic VM Operations

| Task | Command |
|------|---------|
| List VMs | `VBoxManage list vms` |
| List running VMs | `VBoxManage list runningvms` |
| Start VM (GUI) | `VBoxManage startvm "NAME" --type gui` |
| Start VM (headless) | `VBoxManage startvm "NAME" --type headless` |
| Check VM state | `VBoxManage showvminfo "NAME" --machinereadable \| Select-String "^VMState="` |
| Graceful shutdown | `VBoxManage controlvm "NAME" acpipowerbutton` |
| Force power off | `VBoxManage controlvm "NAME" poweroff` |
| Reset VM | `VBoxManage controlvm "NAME" reset` |

### guestcontrol Command Examples (Guest Additions installed)

```powershell
# First: run Step 0 to detect $VBM path
$VM = "Ubuntu-18.04-Server"
$USER = "txl"
$PASS = "newland"

# Check OS version
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "cat /etc/os-release | head -3"

# Check kernel version
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "uname -r"

# Check disk usage
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "df -h /"

# Check memory
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "free -h"

# Check hostname
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "hostname"

# Check uptime
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "uptime"

# Run sudo command (pipe password)
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "echo '$PASS' | sudo -S apt update"

# List files
& $VBM guestcontrol $VM run --exe /bin/bash --username $USER --password $PASS -- bash -c "ls -la /home"
```

### SSH Command Examples

```powershell
# Run a single command via SSH
ssh -o StrictHostKeyChecking=no txl@192.168.5.3 "hostname"

# Run sudo command (prompts for password)
ssh -o StrictHostKeyChecking=no txl@192.168.5.3 "sudo apt update"
```

## Bundled Scripts

- `scripts/vm.ps1` — PowerShell wrapper with functions: `vm-list`, `vm-start`, `vm-stop`, `vm-exec`, `vm-status`
- `references/vboxmanage-cheatsheet.md` — Full VBoxManage command reference
