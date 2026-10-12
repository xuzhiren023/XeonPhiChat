# Phi Chat

Phi Chat 1.5.2 is a Windows desktop chat app for Intel Xeon Phi **Knights Corner** cards. It runs inference on the card, with recent chats, rename/delete, streaming responses, collapsible model reasoning, live token statistics, context usage, and a Stop button that leaves the chat usable.

This is the independent application repository. It has no runtime dependency on Project BluePower, a previous Phi Chat installation, Python, Git, WSL, or a compiler.

## Install

1. Install your KNC card and its **full Intel MPSS Windows driver package**, including the virtual network driver, tools and boot filesystem. Supported profiles are 3120A and 7120P. Knights Landing is not supported. Use Windows 10 1803 or later with Windows PowerShell 5.1 and working MPSS drivers.
2. Download **`PhiChat-1.5.2-Windows.zip`**, extract it to a folder, and double-click **`Setup.cmd`**. Use the Windows installer ZIP, not the source-only ZIP.
3. Accept the Windows UAC prompt with the same Windows account. Setup displays the dedicated Phi adapter, proposed addresses, and installation folder. Save other work running on the card, then type `YES` to initialize it.
4. Setup installs the Windows OpenSSH client if missing, configures the dedicated Phi adapter, creates fresh SSH keys, backs up and rebuilds the MPSS boot image, and boots the card. It verifies the card identity and native runtime, then downloads and checks the first model (LFM2.5 Q5_K_M, about 2 GB).
5. Open the **Phi Chat 1.5.2** desktop shortcut. Connect, load a model, and start chatting. Model downloads and runtime restoration are handled by the app.

Internet access is needed for a missing Windows SSH feature and the initial model download. Allow disk space for downloads, extracted models, and a backup of the MPSS boot image. Install on a local NTFS disk. The default installation is `%LOCALAPPDATA%\Programs\PhiChat\1.5.2`.

The installer does not ship another person's SSH keys, saved chats, host configuration, model approvals, Intel drivers, or Windows system tools. Your existing Project BluePower/Phi Chat copies remain in place.

## Optimized Q5_K models

The default downloadable model and other mixed quantizations use their paired standard runtime. The two uniform Q5_K models use the optimized runtime on supported 7120P hardware and show the green performance check.

To add them, extract **`PhiChat-1.5.1-OptimizedModels.zip`** and run **`Add-Models.cmd`**. Enter the extracted folder containing `models`. Both models are hash-verified before import. The pack contains about 7.4 GB of weights; extraction and installation require additional space. [Model details and upstream licenses](docs/MODELS.md).

That existing two-model pack also works with 1.5.2. The separate **`PhiChat-1.5.2-LFM2.5-8B-A1B-Gaston-Q5_K.zip`** contains the audited Gaston Q5_K weights, requantized from Q8_0. It can be imported for storage, but **cannot be used for chat**: this release has no validated KNC MoE runtime. The model is disabled in the selector and receives no performance badge. See [Gaston status](docs/LFM2-MOE.md).

## Source and releases

Tracked files are application code, setup code, tests, documentation, licenses and immutable asset manifests. Native runtime archives, model weights, generated packages, private identities and installed state are excluded from Git. Local release ZIPs are placed in `dist/`; they are separate distributable assets, not source commits.

```powershell
# Host-only tests; no card or machine configuration changes
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Host.ps1

# Build the source ZIP
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Release.ps1 -SourceOnly

# Build the Windows installer using the three pinned native payloads
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Release.ps1 -AssetsDirectory C:\PhiChatAssets
```

The three payload filenames and exact SHA-256 values are in [runtime-manifest.json](assets/runtime-manifest.json). `-ModelDirectory` can add a separate local model pack from a folder containing the manifest's `models/...` paths. Use `-ModelsOnly` to package weights without rebuilding the Windows ZIP, `-ModelIds` to select an exact subset, and `-ModelPackName` to name the pack (default `LocalModels`). Every ZIP member is read back and hash-checked. The source-only checkout needs these native release assets before installation; it does not silently fetch an unpinned runtime.

No public remote or release URL is configured by this migration. The generated ZIPs are ready for local distribution; public hosting is a separate step.

See [setup and recovery](docs/SETUP.md), [architecture](docs/ARCHITECTURE.md), [validation](docs/VALIDATION.md), and [third-party licenses](LICENSES.md).

