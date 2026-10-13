# Phi Chat local model pack

Extract this ZIP before importing. Keep its `models` directory and filenames intact. This pack contains model weights, not the Windows application.

1. Install Phi Chat 1.6.0 from its separate Windows ZIP.
2. Run `Add-Models.cmd` from the installed application or extracted Windows installer.
3. Enter the extracted pack folder containing `models`. The app checks the complete file sizes and SHA-256 hashes before copying.

Each pack can contain a subset of the models listed in `optimized-models.json`. Missing models are not required unless explicitly selected with `-ModelIds`. The application uses its own pinned manifest; pack metadata cannot grant a new identity or permission to run.

**Gaston and Step3 vision packs are enabled on 7120P in 1.6.0.** Gaston uses the MoE runtime. The Step3-Vision pack contains the matching Q6_K projector; its language weights download when Load model runs. Earlier versions cannot use these new capabilities. Import never fabricates native acceptance or grants a speed badge.

See [model details and upstream license guidance](docs/MODELS.md) and [Gaston audit and runtime status](docs/LFM2-MOE.md). The earlier two dense models remain available in the compatible 1.5.1 OptimizedModels pack. No earlier model pack is required to import the separate Gaston pack.
