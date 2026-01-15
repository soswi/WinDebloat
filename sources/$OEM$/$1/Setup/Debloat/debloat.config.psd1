@{
  # =========================================================
  #  D E B L O A T   C O N F I G
  # =========================================================
  # IMPORTANT / DISCLAIMER:
  # By running this script, you understand that you are tampering with Windows components
  # (built-in apps, features, policies, services). You may lose some
  # functionality (e.g., Store, Xbox, Phone Link, Widgets, Copilot, etc.).
  # The config/script author is NOT responsible for the consequences.
  #
  # If the following is not set to $true – the script will terminate.
  IAgreeAndUnderstand = $false

  # Mode: conservative / balanced / aggressive
  # conservative: minimum risk (recommended for start)
  # balanced: removes typical bloatware apps and disables recommendations
  # aggressive: stronger (higher risk of side effects)
  Preset = "balanced"

  # =========================
  #  A P P X  (Store apps)
  # =========================
  # Note: difference:
  # - Remove-AppxPackage removes the application for the current user,
  # - Remove-AppxProvisionedPackage removes "provisioning" from the image,
  #   so it won't appear for new users.

  Appx = @{
    RemoveProvisioned = $true  # remove provisioned appx (for new accounts)
    RemoveForAllUsers = $false # attempt to remove for existing accounts (not always permanent)

    # Each item has a toggle + comment about effects:
    Packages = @{
      "Microsoft.XboxApp"               = @{ Enabled = $true;  Note = "Removes Xbox app. Effect: no Xbox/Game Pass UI integration." }
      "Microsoft.XboxGamingOverlay"     = @{ Enabled = $true;  Note = "Disables Game Bar/overlay. Effect: no Win+G recording." }
      "Microsoft.XboxGameOverlay"       = @{ Enabled = $true;  Note = "Same as above (overlay)." }
      "Microsoft.GamingApp"             = @{ Enabled = $true;  Note = "Xbox/Gaming Services UI. Effect: issues with MS Store game installation." }

      "Microsoft.BingNews"              = @{ Enabled = $true;  Note = "News. No system effects." }
      "Microsoft.BingWeather"           = @{ Enabled = $true;  Note = "Weather. No system effects." }
      "Microsoft.GetHelp"               = @{ Enabled = $true;  Note = "Get Help. Safe." }
      "Microsoft.Getstarted"            = @{ Enabled = $true;  Note = "Tips/Welcome. Safe." }

      "Microsoft.MicrosoftSolitaireCollection" = @{ Enabled = $true; Note = "Games. Safe." }
      "Microsoft.People"                = @{ Enabled = $true;  Note = "People. Effect: less contact integration." }
      "Microsoft.MicrosoftStickyNotes"  = @{ Enabled = $false; Note = "Sticky Notes. Set true if you don't use it." }

      "Microsoft.WindowsMaps"           = @{ Enabled = $true;  Note = "Maps. Safe." }
      "Microsoft.ZuneMusic"             = @{ Enabled = $true;  Note = "Media Player (legacy components). May affect some audio integrations." }
      "Microsoft.ZuneVideo"             = @{ Enabled = $true;  Note = "Video. Safe." }

      "Microsoft.PowerAutomateDesktop"  = @{ Enabled = $true;  Note = "Power Automate. Safe if unused." }
      "MicrosoftTeams"                  = @{ Enabled = $true;  Note = "Teams consumer. You usually install it separately for work anyway." }
      "MSTeams"                         = @{ Enabled = $true;  Note = "New Teams identifier on some builds." }

      "Microsoft.WindowsFeedbackHub"    = @{ Enabled = $true;  Note = "Feedback Hub. Safe." }
      "Microsoft.YourPhone"             = @{ Enabled = $false; Note = "Phone Link. Note: often linked to 'consumer features' policies." }
      "Microsoft.OneDriveSync"          = @{ Enabled = $false; Note = "OneDrive is often Win32, not Appx — separate toggle below." }
    }
  }

  # =========================
  #  F E A T U R E S / C A P A B I L I T I E S
  # =========================
  # DISM allows removing capabilities / Features on Demand in the image and system.
  Features = @{
    # Caution: some features might be needed (e.g., printing/PDF)
    RemoveCapabilities = $false
    Capabilities = @{
      "MathRecognizer~~~~0.0.1.0" = @{ Enabled = $true;  Note = "Math Recognizer. Safe if unused." }
      "Hello.Face.18967~~~~0.0.1.0" = @{ Enabled = $false; Note = "Windows Hello Face. Set true only if you lack an IR camera and don't use it." }
      "OpenSSH.Client~~~~0.0.1.0" = @{ Enabled = $false; Note = "OpenSSH Client. Keep for dev/servers." }
    }
  }

  # =========================
  #  P R I V A C Y / R E C O M M E N D A T I O N S
  # =========================
  Policies = @{
    DisableConsumerExperiences = $true
    # Note: disabling consumer features may affect integrations like Phone Link in some environments.
    # (This is a real side effect encountered in practice.)

    DisableWidgets = $true     # disables Widgets/News panel
    DisableCopilot = $true     # disables Copilot (if available on your build)
    DisableTipsAndSuggestions = $true
    DisableTailoredExperiences = $true

    # Telemetry – left as a toggle, as it can be controversial and dependent on the system edition.
    SetTelemetryToMinimum = $false
  }

  # =========================
  #  S E R V I C E S / S C H E D U L E D  T A S K S
  # =========================
  Services = @{
    # Rule: only things that are typically "bloat", not critical.
    Disable = @{
      "DiagTrack" = @{ Enabled = $false; Note = "Connected User Experiences and Telemetry. Note: may affect diagnostics." }
      "WSearch"   = @{ Enabled = $false; Note = "Windows Search. Note: slower search in Explorer/Start." }
      "WerSvc"    = @{ Enabled = $false; Note = "Windows Error Reporting. Note: fewer logs on crashes." }
    }
  }

  # =========================
  #  O N E D R I V E
  # =========================
  OneDrive = @{
    Uninstall = $false   # uninstalls OneDrive (Win32). Note: removes integration with Explorer.
    DisableAutoStart = $true
  }

  # =========================
  #  U P D A T E S
  # =========================
  Updates = @{
    # I do not recommend "disabling updates" in 2026 – at most limiting UI/ads.
    DisableDriverAutoInstall = $false
  }

  # =========================
  #  L O G I N G
  # =========================
  Logging = @{
    Verbose = $true
  }
}