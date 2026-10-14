# Phi Chat local model pack

Extract this ZIP before importing. Keep its `models` directory and filenames intact. This pack contains model weights, not the Windows application.

1. Install Phi Chat 1.6.1 from its separate Windows ZIP.
2. Run `Add-Models.cmd` from the installed application or extracted Windows installer.
3. Enter the extracted pack folder containing `models`. The app checks the complete file sizes and SHA-256 hashes before copying.

Each pack can contain a subset of the models listed in `optimized-models.json`. Missing models are not required unless explicitly selected with `-ModelIds`. The application uses its own pinned manifest; pack metadata cannot grant a new identity or permission to run.



Phi Chat 1.6.5 already includes the matching Step3 Q6_K projector in its Windows installer; the older Step3-Vision pack is no longer required. LFM2.5-VL downloads its official decoder and matching F16 projector automatically; it needs no separate pack.
