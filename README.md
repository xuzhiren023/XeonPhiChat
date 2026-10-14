# Phi Chat

Phi Chat 1.6.4 is a Windows desktop chat app for Intel Xeon Phi **Knights Corner** cards. It runs inference on the card, with recent chats, rename/delete, streaming responses, collapsible model reasoning, live token statistics, context usage, image attachments with drag-and-drop, and a Stop button that leaves the chat usable.

This is the independent application repository. It has no runtime dependency on Project BluePower, a previous Phi Chat installation, Python, Git, WSL, or a compiler.

Version 1.6.4 adds the optimized decode3 runtime on 7120P, with resident priming and image-embedding reuse. 7120P application checks passed for LFM2.5 text, vision and image-cache reuse. See [runtime details](docs/DECODE3.md) and [validation](docs/VALIDATION.md).

## Install

1. Install your KNC card and its **full Intel MPSS Windows driver package**, including the virtual network driver, tools and boot filesystem. Supported profiles are 3120A and 7120P. Knights Landing is not supported. Use Windows 10 1803 or later with Windows PowerShell 5.1 and working MPSS drivers.
2. Download **`PhiChat-1.6.4-Windows.zip`**, extract it to a folder, and double-click **`Setup.cmd`**. Use the Windows installer ZIP, not the source-only ZIP.
3. Accept the Windows UAC prompt with the same Windows account. Setup displays the dedicated Phi adapter, proposed addresses, and installation folder. Save other work running on the card, then type `YES` to initialize it.
4. Setup installs the Windows OpenSSH client if missing, configures the dedicated Phi adapter, creates fresh SSH keys, backs up and rebuilds the MPSS boot image, and boots the card. It verifies the card identity and native runtime, then downloads and checks the first model (LFM2.5 Q5_K_M, about 2 GB).
5. Open the **Phi Chat 1.6.4** desktop shortcut. Connect, load a model, and start chatting. Model downloads and runtime restoration are handled by the app.

Internet access is needed for a missing Windows SSH feature and the initial model download. Allow disk space for downloads, extracted models, and a backup of the MPSS boot image. Install on a local NTFS disk. The default installation is `%LOCALAPPDATA%\Programs\PhiChat\1.6.4`.

The installer does not ship another person's SSH keys, saved chats, host configuration, model approvals, Intel drivers, or Windows system tools. Your existing Project BluePower/Phi Chat copies remain in place.

## Optimized Q5_K models

On 7120P, all nine catalog models use the new `61e9799` runtime plus its pinned image-metadata fix. This enables LFM2.5-VL and Step3-VL alongside the existing text models. The 3120A keeps its previous `d57e0e6` runtime and eligible text models; the fixed multimodal build is currently qualified for 7120P only. See [runtime details](docs/IMAGES.md).

The existing optimized LFM/Llama and Gaston packs remain compatible. Gaston is labeled **Text only**; use LFM2.5-VL for pictures. Extract a pack and run **Add-Models.cmd**, selecting the folder containing `models`. Files are checked against the app's pinned hashes.

## Chat with images

In a new chat, select **LFM2.5-VL 3B Q5_K_M**, then **Load model**. Its language weights and matching vision component download automatically (about 2.8 GB total). Step3-VL remains available with the **PhiChat-1.6.0-Step3-Vision.zip** pack imported through **Add-Models.cmd**. Click **+** or drag PNG/JPEG/BMP pictures into the window. Previews can be removed before sending or opened larger by clicking them. You can send an image without typing a message.

Images stay with their original conversation and are replayed for follow-up questions. Image tokens count toward the context meter. The runtime accepts up to four images in one invocation; older complete turns are omitted when needed. Text-only models remain text-only. See [image support and memory requirements](docs/IMAGES.md).

## Source and releases

Tracked files are application code, setup code, tests, documentation, licenses and immutable asset manifests. Native runtime archives, model weights, generated packages, private identities and installed state are excluded from Git. Local release ZIPs are placed in `dist/`; they are separate distributable assets, not source commits.

The Windows installer contains the app and its setup dependencies. Developer tests, build tools, CI and repository metadata stay in the source ZIP. Run the development commands below from the source checkout. Normal installation checks runtime compatibility but does not run throughput benchmarks.

```powershell
# Host-only tests; no card or machine configuration changes
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Host.ps1

# Build the source ZIP
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Release.ps1 -SourceOnly

# Build the Windows installer using the three pinned native payloads
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Build-Release.ps1 -AssetsDirectory C:\PhiChatAssets
```

The three payload filenames and exact SHA-256 values are in [runtime-manifest.json](assets/runtime-manifest.json). `-ModelDirectory` can add a separate local model pack from a folder containing the manifest's `models/...` paths. Use `-ModelsOnly` to package weights without rebuilding the Windows ZIP, `-ModelIds` to select an exact subset, and `-ModelPackName` to name the pack (default `LocalModels`). Every ZIP member is read back and hash-checked. The source-only checkout needs these native release assets before installation; it does not silently fetch an unpinned runtime.

The source repository is [xuzhiren023/XeonPhiChat](https://github.com/xuzhiren023/XeonPhiChat). Installer and model ZIPs are separate release assets; the GitHub source download does not include those payloads.

See [setup and recovery](docs/SETUP.md), [architecture](docs/ARCHITECTURE.md), [validation](docs/VALIDATION.md), and [third-party licenses](LICENSES.md).

