# Models

Phi Chat 1.6.1 enables all nine pinned catalog models on 7120P through the shared multimodal runtime. LFM2.5-VL and Step3-VL accept images; the other seven accept text. Gaston is explicitly labeled **Text only**. The 3120A retains its previous runtime and eligible text models. TinyDolphin keeps its ChatML template and is distinct from the retired Dolphin-phi2 and TinyLlama models.

Model profiles pin repositories, revisions, complete file sizes and SHA-256 values. Load downloads supported upstream language weights automatically. Generated Q5_K weights and the generated Q6_K vision projector use separately imported packs. [Image instructions](IMAGES.md).

## Optional optimized pack

Extract the pack and point `Add-Models.cmd` at the folder containing `models`. For a custom installation, use `Setup.ps1 -Mode AddModels -Destination <installed-folder> -ModelPackDirectory <extracted-pack>`.

An extracted pack may contain any nonempty subset of the locally pinned model manifest. Use `-ModelIds <id>` with `-Mode AddModels` to require a particular model. Unknown identities and corrupted files are rejected; importing weights never grants runtime acceptance. This permits separate model downloads without re-downloading earlier packs.

| Model | File size | Engine |
| --- | ---: | --- |
| LFM2.5-2.6B uniform matrix Q5_K | 1,863,428,096 bytes | Optimized, 7120P |
| Llama-3.3-8B Instruct 128K Abliterated uniform matrix Q5_K | 5,529,527,392 bytes | Optimized, 7120P |
| LFM2.5-8B-A1B Uncensored Gaston matrix Q5_K | 5,830,593,408 bytes | Shared engine, text only, 7120P |

These are generated quantizations, not upstream Hugging Face filenames. They are distributed separately and are verified against `assets/optimized-models.json`. No invented download URL or fallback to another weight format is used. The default mixed LFM model works without this pack.

Model licenses belong to their upstream authors; app/kernel code licenses do not grant rights to model weights. The complete model profiles include `repository`, `revision` and `upstream_repository` provenance. Review the license/model card at the pinned repository before redistributing weights. The local pack is assembled from the existing approved local models; no public upload occurs during packaging.
The first two models remain available in `PhiChat-1.5.1-OptimizedModels.zip`, compatible with 1.6.1. Gaston uses the separate `PhiChat-1.5.2-LFM2.5-8B-A1B-Gaston-Q5_K.zip` and runs text conversations through the same shared engine. All expert weights are included in memory accounting. [Gaston details](LFM2-MOE.md).

The Step3-VL language model is 5,851,113,280 bytes. Its matching Q6_K projector is 1,893,755,040 bytes, generated from the pinned F16 projector. Both are required for images; the projector is distributed in `PhiChat-1.6.0-Step3-Vision.zip`. Step3-VL is Apache-2.0; see the [upstream model card](https://huggingface.co/stepfun-ai/Step3-VL-10B). Full artifact identities and conversion provenance are in the app profile.

To import just Gaston after extracting its ZIP:

```powershell
.\Setup.ps1 -Mode AddModels -Destination 'D:\Apps\PhiChat\1.6.1' -ModelPackDirectory 'D:\Downloads\Gaston' -ModelIds lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k
```

## LFM2.5-VL image chat

LFM2.5-VL 3B Q5_K_M uses its own trained vision component and accepts pictures on 7120P. Both files download from the official LiquidAI repository at the immutable revision pinned in the app profile. The 1,939,744,800-byte decoder and 853,993,952-byte F16 projector require about 2.8 GB on Windows, plus inference memory on the card. See [image use](IMAGES.md).

