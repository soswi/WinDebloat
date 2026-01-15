param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigPath,

  [string]$LogPath = "C:\Setup\Debloat\debloat.log"
)

function LogWinDebloat($msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $msg"
  $line | Tee-Object -FilePath $LogPath -Append | Out-Null
}

function Require-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Run as Administrator." }
}

function Load-Config($path) {
  if (-not (Test-Path $path)) { throw "Config not found: $path" }
  return Import-PowerShellDataFile -Path $path
}

function Ensure-Agree($cfg) {
  if (-not $cfg.IAgreeAndUnderstand) {
    Log "IAgreeAndUnderstand != true. Exiting without changes."
    exit 2
  }
}

function Remove-ProvisionedAppx($packageName) {
  # Removes provisioning from the system image (online), so it doesn't install for new users.
  $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $packageName }
  if ($null -ne $prov) {
    Log "Removing provisioned Appx: $packageName"
    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName | Out-Null
  } else {
    Log "Provisioned Appx not found: $packageName (skipping)"
  }
}

function Remove-AppxForCurrentUser($packageName) {
  $pkgs = Get-AppxPackage -Name $packageName -AllUsers -ErrorAction SilentlyContinue
  foreach ($p in $pkgs) {
    try {
      Log "Removing Appx (per-user): $($p.Name) for user scope (best effort)"
      Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue
    } catch {
      # FIX: Used ${packageName} to prevent PowerShell parser error with the colon
      Log "Failed Remove-AppxPackage for ${packageName}: $($_.Exception.Message)"
    }
  }
}

function Set-RegDword($path, $name, $value) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name $name -PropertyType DWord -Value $value -Force | Out-Null
  # FIX: Used ${path} to ensure safe parsing if path contains complex characters
  Log "REG DWORD set: ${path}\$name = $value"
}

function Disable-Widgets {
  # Simple, "best effort" — Microsoft can change behaviors between builds.
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
}

function Disable-Copilot {
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
}

function Disable-Tips {
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsSpotlightFeatures" 1
}

function Disable-ConsumerExperiences {
  # "Turn off Microsoft consumer experiences" maps to CloudContent policies (admin practice).
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
}

function Disable-ServiceIfEnabled($svcName) {
  $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
  if ($null -eq $svc) { Log "Service not found: $svcName (skip)"; return }
  Log "Disabling service: $svcName"
  try {
    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svcName -StartupType Disabled
  } catch {
    Log "Failed to disable service ${svcName}: $($_.Exception.Message)"
  }
}

function Uninstall-OneDrive {
  # OneDrive is usually Win32, not Appx
  $od = "$env:SystemRoot\System32\OneDriveSetup.exe"
  if (Test-Path $od) {
    Log "Uninstalling OneDrive (best effort)"
    Start-Process -FilePath $od -ArgumentList "/uninstall" -Wait -WindowStyle Hidden
  } else {
    Log "OneDriveSetup.exe not found (skip)"
  }
}

# =========================
# MAIN
# =========================
try {
  Require-Admin
  New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null

  $cfg = Load-Config $ConfigPath
  Ensure-Agree $cfg

  Log "Debloat started. Preset=$($cfg.Preset)"

  # Appx
  if ($cfg.Appx.RemoveProvisioned -or $cfg.Appx.RemoveForAllUsers) {
    foreach ($k in $cfg.Appx.Packages.Keys) {
      $item = $cfg.Appx.Packages[$k]
      if ($item.Enabled -eq $true) {
        if ($cfg.Appx.RemoveProvisioned) { Remove-ProvisionedAppx $k }
        if ($cfg.Appx.RemoveForAllUsers) { Remove-AppxForCurrentUser $k }
      } else {
        Log "Appx toggle disabled: $k"
      }
    }
  }

  # Policies
  if ($cfg.Policies.DisableConsumerExperiences) { Disable-ConsumerExperiences }
  if ($cfg.Policies.DisableWidgets) { Disable-Widgets }
  if ($cfg.Policies.DisableCopilot) { Disable-Copilot }
  if ($cfg.Policies.DisableTipsAndSuggestions) { Disable-Tips }

  # Services
  foreach ($svcName in $cfg.Services.Disable.Keys) {
    $svcItem = $cfg.Services.Disable[$svcName]
    if ($svcItem.Enabled -eq $true) { Disable-ServiceIfEnabled $svcName }
  }

  # OneDrive
  if ($cfg.OneDrive.DisableAutoStart) {
    Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
  }
  if ($cfg.OneDrive.Uninstall) { Uninstall-OneDrive }

  # Revert IAgreeAndUnderstand to $false in the config file for safety
  try {
    $rawConfig = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
    # Replace 'IAgreeAndUnderstand = $true' with 'IAgreeAndUnderstand = $false'
    # Using regex to handle potential whitespace variations
    if ($rawConfig -match "IAgreeAndUnderstand\s*=\s*\$true") {
        $newConfig = $rawConfig -replace "IAgreeAndUnderstand\s*=\s*\$true", "IAgreeAndUnderstand = `$false"
        Set-Content -Path $ConfigPath -Value $newConfig -ErrorAction Stop
        Log "Security: Config file updated. IAgreeAndUnderstand reverted to `$false."
    }
  } catch {
    Log "Warning: Failed to revert IAgreeAndUnderstand in config file: $($_.Exception.Message)"
  }

  Log "Debloat finished successfully."
  exit 0
}
catch {
  Log "FATAL: $($_.Exception.Message)"
  exit 1
}