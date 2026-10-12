# Models

Mixed Q5_K_M and Q2_K models use the standard modern runtime. The two qualified dense uniform matrix Q5_K models use the separately paired optimized engine on supported 7120P hardware. Q5_K quantization alone does not imply runtime support. TinyDolphin uses its historical engine; it is distinct from the retired Dolphin-phi2 and TinyLlama models, which are not included.

Model profiles in `app/config/models` pin repositories, revisions, complete file sizes and SHA-256 values. Load downloads supported upstream files automatically and checks the complete hash. Hardware memory and context budgets remain dynamic. The disabled Step3-VL profile is retained as an explicit unsupported-architecture test case, not an available chat model.

## Optional optimized pack

Extract the pack and point `Add-Models.cmd` at the folder containing `models`. For a custom installation, use `Setup.ps1 -Mode AddModels -Destination <installed-folder> -ModelPackDirectory <extracted-pack>`.

An extracted pack may contain any nonempty subset of the locally pinned model manifest. Use `-ModelIds <id>` with `-Mode AddModels` to require a particular model. Unknown identities and corrupted files are rejected; importing weights never grants runtime acceptance. This permits separate model downloads without re-downloading earlier packs.

| Model | File size | Engine |
| --- | ---: | --- |
| LFM2.5-2.6B uniform matrix Q5_K | 1,863,428,096 bytes | Optimized, 7120P |
| Llama-3.3-8B Instruct 128K Abliterated uniform matrix Q5_K | 5,529,527,392 bytes | Optimized, 7120P |
| LFM2.5-8B-A1B Uncensored Gaston matrix Q5_K | 5,830,593,408 bytes | Unavailable: KNC MoE runtime not qualified |

These are generated quantizations, not upstream Hugging Face filenames. They are distributed separately and are verified against `assets/optimized-models.json`. No invented download URL or fallback to another weight format is used. The default mixed LFM model works without this pack.

Model licenses belong to their upstream authors; app/kernel code licenses do not grant rights to model weights. The complete model profiles include `repository`, `revision` and `upstream_repository` provenance. Review the license/model card at the pinned repository before redistributing weights. The local pack is assembled from the existing approved local models; no public upload occurs during packaging.

The first two models remain available in `PhiChat-1.5.1-OptimizedModels.zip`, compatible with 1.5.2. Gaston is a separate `PhiChat-1.5.2-LFM2.5-8B-A1B-Gaston-Q5_K.zip` so existing models need not be downloaded again. Its Q5_K weights were requantized from the pinned Q8_0 source, without a new imatrix. It uses `lfm2moe`, which is blocked by the current native runner. Import stores the exact audited file; it does not enable chat or confer the green performance check. See [integration status and required validation](LFM2-MOE.md).

To import just Gaston after extracting its ZIP:

```powershell
.\Setup.ps1 -Mode AddModels -Destination 'D:\Apps\PhiChat\1.5.2' -ModelPackDirectory 'D:\Downloads\Gaston' -ModelIds lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k
```

