# LFM2.5-8B-A1B Gaston integration status

**Phi Chat 1.6.0 enables this model on 7120P with the pinned `61e9799` multimodal runtime.** Earlier app versions deliberately blocked it. Existing Gaston Q5_K packs remain compatible. The selector does not claim a speed advantage or inherit the dense models' numerical acceptance.

The requested [Gaston checkpoint](https://huggingface.co/gaston-parravicini/LFM2.5-8B-A1B-Uncensored-Gaston-GGUF) is pinned to revision `c4e8cb570263f2d6f79911f3ecf3538d143d682f`. Its GGUF header reports `lfm2moe`, 24 blocks, embedding width 2048, 128,000-token training context, 32 experts with 4 selected per token, 2 leading dense blocks, 18 short convolutions and 6 attention blocks. The published Q8_0 source is 9,010,195,616 bytes with SHA-256 `a3bd5a242606e7a3af2950a2377e2411dadf4afa9883199a948cb8c834af38f9`.

## Audited local artifact

`LFM2.5-8B-A1B-Uncensored-Gaston-MATRICES-Q5_K.gguf` is **5,830,593,408 bytes**. Its complete SHA-256 was independently checked during integration:

```text
852cd73ed6ba7d8fcd6ebeae577a75fa7de5f3239c9fe0dce7bf8cc077e20ec3
```

This is an explicitly approved **Q8_0 requantization**, not an F16 conversion. No imatrix was used for this conversion. The producer used llama.cpp b11552, commit `23b0202a189c44a54625aadcb37a946dd1d6278d`, with a separate router conversion through the same pinned `ggml-base.dll`.

The retained audit inventories all 256 tensors: 155 Q5_K (67 ordinary matrices, 66 packed expert matrices and 22 router matrices) and 101 F32 exceptions (61 normalization tensors, 18 short convolutions and 22 routing biases). All F32 exceptions are byte-identical to the source. All Q5 block scales were checked for finiteness. Numerical sampling covered all 2,112 expert slices at three rows per slice, with maximum sampled relative RMSE 0.0546457183610032 against Q8_0. These checks describe the conversion; they do not establish model quality or native execution.

The [sanitized provenance receipt](../assets/model-provenance/lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k.json) pins the source, quantizer and original producer receipt. The [unaltered tensor audit](../assets/model-provenance/lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k.audit.json) has SHA-256 `0bdd3dae4be8886e8975c63c485a8142091f89f2036f8cd2888b113a10cece8a`. Both accompany the separate model pack. No public Q5_K download URL is invented.

## Runtime and resources

The new runtime includes indexed expert multiplication and LFM2-MoE state. The exact runtime archive, executable hash and source fix are pinned independently of the old runtimes. Other card profiles cannot inherit the 7120P build.

The GGUF reader uses the checkpoint's per-layer KV heads. Six attention blocks, eight KV heads and 64-dimensional keys/values give 12,288 F16 KV bytes per token. The app separately budgets routed expert intermediates, routing values, short-convolution state and the **complete** GGUF weight file. Four active experts do not imply four resident experts. Context and batch are selected from model metadata and currently available RAM, with the native memory/thermal/Stop guard retained.

The prompt follows the actual GGUF template: start-of-text, ChatML turns and an assistant header, without a forced thinking prefix. Model-emitted `<think>` tags still appear in the collapsible reasoning panel.

Import accepts a nonempty subset of the pinned model manifest and preserves existing files. Conversion audits remain separate from runtime testing. See [validation](VALIDATION.md) for the scoped hardware results.
