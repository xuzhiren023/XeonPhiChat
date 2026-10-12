# Models

Mixed Q5_K_M and Q2_K models use the standard modern runtime. Uniform matrix Q5_K models use the separately paired optimized engine when the detected hardware supports it. TinyDolphin uses its historical engine; it is distinct from the retired Dolphin-phi2 and TinyLlama models, which are not included.

Model profiles in `app/config/models` pin repositories, revisions, complete file sizes and SHA-256 values. Load downloads supported upstream files automatically and checks the complete hash. Hardware memory and context budgets remain dynamic. The disabled Step3-VL profile is retained as an explicit unsupported-architecture test case, not an available chat model.

## Optional optimized pack

Extract the pack and point `Add-Models.cmd` at the folder containing `models`. For a custom installation, use `Setup.ps1 -Mode AddModels -Destination <installed-folder> -ModelPackDirectory <extracted-pack>`.

| Model | File size | Engine |
| --- | ---: | --- |
| LFM2.5-2.6B uniform matrix Q5_K | 1,863,428,096 bytes | Optimized, 7120P |
| Llama-3.3-8B Instruct 128K Abliterated uniform matrix Q5_K | 5,529,527,392 bytes | Optimized, 7120P |

These are generated quantizations, not upstream Hugging Face filenames. They are distributed separately and are verified against `assets/optimized-models.json`. No invented download URL or fallback to another weight format is used. The default mixed LFM model works without this pack.

Model licenses belong to their upstream authors; app/kernel code licenses do not grant rights to model weights. The complete model profiles include `repository`, `revision` and `upstream_repository` provenance. Review the license/model card at the pinned repository before redistributing weights. The local pack is assembled from the existing approved local models; no public upload occurs during packaging.

