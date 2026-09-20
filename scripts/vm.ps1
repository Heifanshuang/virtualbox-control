# vm.ps1 — VirtualBox VM control wrapper
# Usage:
#   . .\vm.ps1                # load functions into session
#   vm-list                   # list all VMs
#   vm-status "UbuntuServer"  # show VM state
#   vm-start "UbuntuServer"   # start in GUI mode
#   vm-start "UbuntuServer" headless
#   vm-exec "UbuntuServer" "user" "pass" "ls -la"
#   vm-stop "UbuntuServer"    # graceful ACPI shutdown
#   vm-stop "UbuntuServer" force  # poweroff

$VBM = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

function vm-list {
    Write-Host "=== All VMs ==="
    & $VBM list vms
    Write-Host "`n=== Running VMs ==="
    & $VBM list runningvms
}

function vm-status([string]$Name) {
    $info = & $VBM showvminfo $Name --machinereadable 2>&1
    $state = ($info | Select-String '^VMState=').ToString().Split('"')[1]
    Write-Host "VM: $Name"
    Write-Host "State: $state"
    return $state
}

function vm-start([string]$Name, [string]$Mode = "gui") {
    $running = & $VBM list runningvms 2>&1
    if ($running -match [regex]::Escape("`"$Name`"")) {
        Write-Host "VM '$Name' is already running."
        return
    }
    Write-Host "Starting '$Name' in $Mode mode..."
    & $VBM startvm $Name --type $Mode
    Write-Host "Waiting for guest boot (20s)..."
    Start-Sleep -Seconds 20
    $state = vm-status $Name
    Write-Host "Current state: $state"
}

function vm-exec([string]$Name, [string]$User, [string]$Pass, [string]$Cmd) {
    Write-Host "Executing in '$Name': $Cmd"
    & $VBM guestcontrol $Name run `
        --exe /bin/bash `
        --username $User `
        --password $Pass `
        -- -c $Cmd
}

function vm-stop([string]$Name, [string]$Mode = "graceful") {
    if ($Mode -eq "force") {
        Write-Host "Force powering off '$Name'..."
        & $VBM controlvm $Name poweroff
    } else {
        Write-Host "Sending ACPI shutdown to '$Name'..."
        & $VBM controlvm $Name acpipowerbutton
        Write-Host "Waiting for shutdown (15s)..."
        Start-Sleep -Seconds 15
    }
    $state = vm-status $Name
    Write-Host "Final state: $state"
}

Write-Host "vm.ps1 loaded. Available: vm-list, vm-status, vm-start, vm-exec, vm-stop"
