param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigPath,

  [string]$LogPath = "C:\Setup\Debloat\debloat.log"
)

function Write-Log($msg) {
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $msg"
  $line | Tee-Object -FilePath $LogPath -Append | Out-Null
}

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { throw "Run as Administrator." }
}

function Import-ConfigData($path) {
  if (-not (Test-Path $path)) { throw "Config not found: $path" }
  return Import-PowerShellDataFile -Path $path
}

function Assert-Agreement($cfg) {
  if (-not $cfg.IAgreeAndUnderstand) {
    Write-Log "IAgreeAndUnderstand != true. Exiting without changes."
    exit 2
  }
}

# --- Appx Functions ---
function Remove-ProvisionedAppx($packageName) {
  $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $packageName }
  if ($null -ne $prov) {
    Write-Log "Removing provisioned Appx: $packageName"
    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName | Out-Null
  } else {
    Write-Log "Provisioned Appx not found: $packageName (skipping)"
  }
}

function Remove-AppxForCurrentUser($packageName) {
  $pkgs = Get-AppxPackage -Name $packageName -AllUsers -ErrorAction SilentlyContinue
  foreach ($p in $pkgs) {
    try {
      Write-Log "Removing Appx (per-user): $($p.Name) for user scope (best effort)"
      Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue
    } catch {
      Write-Log "Failed Remove-AppxPackage for ${packageName}: $($_.Exception.Message)"
    }
  }
}

# --- Registry Functions ---
function Set-RegDword($path, $name, $value) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name $name -PropertyType DWord -Value $value -Force | Out-Null
  Write-Log "REG DWORD set: ${path}\$name = $value"
}

function Set-RegString($path, $name, $value) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  New-ItemProperty -Path $path -Name $name -PropertyType String -Value $value -Force | Out-Null
  Write-Log "REG STRING set: ${path}\$name = '$value'"
}

function Apply-RegistryTweak($tweakKey, $tweakData) {
    Write-Log "Applying Tweak: $tweakKey"
    if ($tweakData.Type -eq "String") {
        Set-RegString -Path $tweakData.Path -Name $tweakData.Name -Value $tweakData.Value
    }
    elseif ($tweakData.Type -eq "DWord") {
        Set-RegDword -Path $tweakData.Path -Name $tweakData.Name -Value $tweakData.Value
    }
    else {
        Write-Log "Unknown Registry Type for tweak $tweakKey"
    }
}

# --- Policy Helper Functions ---
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

function Disable-TailoredExperiences {
  # Disables "Tailored experiences with diagnostic data"
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableTailoredExperiencesWithDiagnosticData" 1
  
  # Attempts to disable for current user privacy settings
  $privacyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
  if (Test-Path $privacyPath) {
     Set-RegDword $privacyPath "TailoredExperiencesAllowed" 0
  }
}

function Set-TelemetryToMinimum {
  # Sets AllowTelemetry to 1 (Basic/Required). 
  # Note: Setting to 0 (Security) is only effective on Enterprise/Education/Server editions.
  Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1
}

# --- Services / OneDrive ---
function Disable-ServiceIfEnabled($svcName) {
  $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
  if ($null -eq $svc) { Write-Log "Service not found: $svcName (skip)"; return }
  Write-Log "Disabling service: $svcName"
  try {
    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svcName -StartupType Disabled
  } catch {
    Write-Log "Failed to disable service ${svcName}: $($_.Exception.Message)"
  }
}

function Uninstall-OneDrive {
  # OneDrive is usually Win32, not Appx
  $od = "$env:SystemRoot\System32\OneDriveSetup.exe"
  if (Test-Path $od) {
    Write-Log "Uninstalling OneDrive (best effort)"
    Start-Process -FilePath $od -ArgumentList "/uninstall" -Wait -WindowStyle Hidden
  } else {
    Write-Log "OneDriveSetup.exe not found (skip)"
  }
}

# =========================
# MAIN
# =========================
try {
  Assert-Admin
  New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null

  $cfg = Import-ConfigData $ConfigPath
  Assert-Agreement $cfg

  Write-Log "Debloat started. Preset=$($cfg.Preset)"

  # 1. Appx Removal
  if ($cfg.Appx.RemoveProvisioned -or $cfg.Appx.RemoveForAllUsers) {
    foreach ($k in $cfg.Appx.Packages.Keys) {
      $item = $cfg.Appx.Packages[$k]
      if ($item.Enabled -eq $true) {
        if ($cfg.Appx.RemoveProvisioned) { Remove-ProvisionedAppx $k }
        if ($cfg.Appx.RemoveForAllUsers) { Remove-AppxForCurrentUser $k }
      } else {
        Write-Log "Appx toggle disabled: $k"
      }
    }
  }

  # 2. General Policies
  if ($cfg.Policies.DisableConsumerExperiences) { Disable-ConsumerExperiences }
  if ($cfg.Policies.DisableWidgets) { Disable-Widgets }
  if ($cfg.Policies.DisableCopilot) { Disable-Copilot }
  if ($cfg.Policies.DisableTipsAndSuggestions) { Disable-Tips }
  
  # Added missing implementation:
  if ($cfg.Policies.DisableTailoredExperiences) { Disable-TailoredExperiences }
  if ($cfg.Policies.SetTelemetryToMinimum) { Set-TelemetryToMinimum }

  # 3. Custom Registry Tweaks
  if ($cfg.Tweaks) {
    foreach ($k in $cfg.Tweaks.Keys) {
        $tweak = $cfg.Tweaks[$k]
        if ($tweak.Enabled -eq $true) {
            Apply-RegistryTweak -tweakKey $k -tweakData $tweak
        }
    }
  }

  # 4. Services
  foreach ($svcName in $cfg.Services.Disable.Keys) {
    $svcItem = $cfg.Services.Disable[$svcName]
    if ($svcItem.Enabled -eq $true) { Disable-ServiceIfEnabled $svcName }
  }

  # 5. OneDrive
  if ($cfg.OneDrive.DisableAutoStart) {
    Set-RegDword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
  }
  if ($cfg.OneDrive.Uninstall) { Uninstall-OneDrive }

  # Security: Revert IAgreeAndUnderstand to $false
  try {
    $rawConfig = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
    # Replace 'IAgreeAndUnderstand = $true' with 'IAgreeAndUnderstand = $false'
    # Using regex to handle potential whitespace variations
    if ($rawConfig -match "IAgreeAndUnderstand\s*=\s*\$true") {
        $newConfig = $rawConfig -replace "IAgreeAndUnderstand\s*=\s*\$true", "IAgreeAndUnderstand = `$false"
        Set-Content -Path $ConfigPath -Value $newConfig -ErrorAction Stop
        Write-Log "Security: Config file updated. IAgreeAndUnderstand reverted to `$false."
    }
  } catch {
    Write-Log "Warning: Failed to revert IAgreeAndUnderstand in config file: $($_.Exception.Message)"
  }

  Write-Log "Debloat finished successfully."
  exit 0
}
catch {
  Write-Log "FATAL: $($_.Exception.Message)"
  exit 1
}