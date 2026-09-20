# VBoxManage Cheatsheet

Full command reference for VirtualBox 6.1.x. Use the full path:
`C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`

---

## 1. VM Lifecycle

```bash
# List all registered VMs
VBoxManage list vms

# List running VMs only
VBoxManage list runningvms

# Start VM in GUI mode (opens console window)
VBoxManage startvm "VM_NAME" --type gui

# Start VM headless (no window, background)
VBoxManage startvm "VM_NAME" --type headless

# Start VM in a separate debug/VM window
VBoxManage startvm "VM_NAME" --type separate

# Graceful shutdown (ACPI signal)
VBoxManage controlvm "VM_NAME" acpipowerbutton

# Force power off (hard stop)
VBoxManage controlvm "VM_NAME" poweroff

# Save VM state (freeze & resume)
VBoxManage controlvm "VM_NAME" savestate

# Pause / resume
VBoxManage controlvm "VM_NAME" pause
VBoxManage controlvm "VM_NAME" resume

# Reboot
VBoxManage controlvm "VM_NAME" reset
```

## 2. VM Info

```bash
# Full info (human-readable)
VBoxManage showvminfo "VM_NAME"

# Machine-readable output (parsable)
VBoxManage showvminfo "VM_NAME" --machinereadable

# Filter specific values in PowerShell
VBoxManage showvminfo "VM_NAME" --machinereadable | Select-String "^VMState="
VBoxManage showvminfo "VM_NAME" --machinereadable | Select-String "^memory="
```

## 3. Guest Control (Run Commands Inside VM)

Requires Guest Additions installed and running in the guest.

```bash
# Run a command
VBoxManage guestcontrol "VM_NAME" run \
  --exe /bin/bash \
  --username USER \
  --password PASS \
  -- -c "ls -la /home"

# Run with environment variables
VBoxManage guestcontrol "VM_NAME" run \
  --exe /usr/bin/python3 \
  --username USER --password PASS \
  --env "MY_VAR=hello" \
  -- /home/user/script.py

# Copy file FROM host TO guest
VBoxManage guestcontrol "VM_NAME" copyfromhost "C:\local\file.txt" \
  --target-directory /home/user/ \
  --username USER --password PASS

# Copy file FROM guest TO host
VBoxManage guestcontrol "VM_NAME" copytohost /home/user/output.log \
  --target-directory "C:\local\" \
  --username USER --password PASS

# List guest directory
VBoxManage guestcontrol "VM_NAME" list \
  --username USER --password PASS \
  --directory /home/user
```

## 4. Snapshots

```bash
# List snapshots
VBoxManage snapshot "VM_NAME" list

# Take a snapshot
VBoxManage snapshot "VM_NAME" take "SNAP_NAME" --description "before upgrade"

# Restore a snapshot
VBoxManage snapshot "VM_NAME" restore "SNAP_NAME"

# Restore to current state (discard changes since last snapshot)
VBoxManage snapshot "VM_NAME" restorecurrent

# Delete a snapshot
VBoxManage snapshot "VM_NAME" delete "SNAP_NAME"
```

## 5. Networking

```bash
# Show NIC config
VBoxManage showvminfo "VM_NAME" --machinereadable | Select-String "nic|bridgehost|hostonlyadapter"

# List host-only interfaces
VBoxManage list hostonlyifs

# List port forwarding rules (NAT)
VBoxManage showvminfo "VM_NAME" --machinereadable | Select-String "Forwarding"

# Add port forwarding rule (host port 8080 -> guest port 80)
VBoxManage modifyvm "VM_NAME" --natpf1 "rule-name,tcp,,8080,,80"

# Delete port forwarding rule
VBoxManage modifyvm "VM_NAME" --natpf1 delete "rule-name"
```

## 6. Shared Folders

```bash
# Add shared folder (permanent)
VBoxManage sharedfolder add "VM_NAME" \
  --name "myshare" \
  --hostpath "C:\Shared" \
  --automount

# Remove shared folder
VBoxManage sharedfolder remove "VM_NAME" --name "myshare"

# List shared folders
VBoxManage showvminfo "VM_NAME" --machinereadable | Select-String "SharedFolder"
```

## 7. Disk & Storage

```bash
# List all virtual disks
VBoxManage list hdds

# Show disk info
VBoxManage showhdinfo "C:\path\to\disk.vdi"

# Create new disk
VBoxManage createmedium disk --filename "C:\vms\new-disk.vdi" --size 20480

# Resize disk (must be powered off)
VBoxManage modifymedium disk "C:\vms\disk.vdi" --resize 40960

# Clone disk
VBoxManage clonemedium "source.vdi" "dest.vdi"
```

## 8. VM Creation (reference)

```bash
# Create a new VM
VBoxManage createvm --name "NewVM" --ostype Ubuntu_64 --register

# Configure
VBoxManage modifyvm "NewVM" --memory 2048 --cpus 2 --nic1 nat

# Add storage controller
VBoxManage storagectl "NewVM" --name "SATA" --add sata --controller IntelAhci

# Attach disk
VBoxManage storageattach "NewVM" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "disk.vdi"

# Attach ISO (install media)
VBoxManage storageattach "NewVM" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "ubuntu.iso"
```

## 9. Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `VBoxManage.exe not found` | Not in PATH | Use full path |
| `VM is not running` | guestcontrol called before boot | Wait for boot, check state |
| `Guest Additions not running` | GA not installed/started | Install GA in guest, reboot |
| `Authentication failed` | Wrong guest credentials | Ask user for correct user/pass |
| `The object already exists` | VM/disk already registered | Check existing list first |
| `Could not open medium` | Disk locked by another VM | Close other VM or release medium |
