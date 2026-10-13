# Phi Chat local model pack

Extract this ZIP before importing. Keep its `models` directory and filenames intact. This pack contains model weights, not the Windows application.

1. Install Phi Chat 1.5.7 from its separate Windows ZIP.
2. Run `Add-Models.cmd` from the installed application or extracted Windows installer.
3. Enter the extracted pack folder containing `models`. The app checks the complete file sizes and SHA-256 hashes before copying.

Each pack can contain a subset of the models listed in `optimized-models.json`. Missing models are not required unless explicitly selected with `-ModelIds`. The application uses its own pinned manifest; pack metadata cannot grant a new identity or permission to run.

**LFM2.5-8B-A1B Gaston cannot run in this release.** Its audited Q5_K weights can be stored for later use, but the current KNC runtime does not support its MoE architecture. Import reports this limitation, and the model stays disabled without a green performance badge. These weights were requantized from Q8_0 without a new imatrix.

See [model details and upstream license guidance](docs/MODELS.md) and [Gaston audit and runtime status](docs/LFM2-MOE.md). The earlier two dense models remain available in the compatible 1.5.1 OptimizedModels pack. No earlier model pack is required to import the separate Gaston pack.
