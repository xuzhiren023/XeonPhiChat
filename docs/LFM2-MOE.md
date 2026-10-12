# LFM2.5-8B-A1B Gaston integration status

**The audited weights can be imported in Phi Chat 1.5.2, but the shipped KNC runtime cannot run this model.** The catalog entry is disabled with a runtime-unavailable label. Import does not enable chat or grant native acceptance.

The requested [Gaston checkpoint](https://huggingface.co/gaston-parravicini/LFM2.5-8B-A1B-Uncensored-Gaston-GGUF) is pinned to revision `c4e8cb570263f2d6f79911f3ecf3538d143d682f`. Its GGUF header reports `lfm2moe`, 24 blocks, embedding width 2048, 128,000-token training context, 32 experts with 4 selected per token, 2 leading dense blocks, 18 short convolutions and 6 attention blocks. The published Q8_0 source is 9,010,195,616 bytes with SHA-256 `a3bd5a242606e7a3af2950a2377e2411dadf4afa9883199a948cb8c834af38f9`.

## Audited local artifact

`LFM2.5-8B-A1B-Uncensored-Gaston-MATRICES-Q5_K.gguf` is **5,830,593,408 bytes**. Its complete SHA-256 was independently checked during integration:

```text
852cd73ed6ba7d8fcd6ebeae577a75fa7de5f3239c9fe0dce7bf8cc077e20ec3
```

This is an explicitly approved **Q8_0 requantization**, not an F16 conversion. No imatrix was used for this conversion. The producer used llama.cpp b11552, commit `23b0202a189c44a54625aadcb37a946dd1d6278d`, with a separate router conversion through the same pinned `ggml-base.dll`.

The retained audit inventories all 256 tensors: 155 Q5_K (67 ordinary matrices, 66 packed expert matrices and 22 router matrices) and 101 F32 exceptions (61 normalization tensors, 18 short convolutions and 22 routing biases). All F32 exceptions are byte-identical to the source. All Q5 block scales were checked for finiteness. Numerical sampling covered all 2,112 expert slices at three rows per slice, with maximum sampled relative RMSE 0.0546457183610032 against Q8_0. These checks describe the conversion; they do not establish model quality or native execution.

The [sanitized provenance receipt](../assets/model-provenance/lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k.json) pins the source, quantizer and original producer receipt. The [unaltered tensor audit](../assets/model-provenance/lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k.audit.json) has SHA-256 `0bdd3dae4be8886e8975c63c485a8142091f89f2036f8cd2888b113a10cece8a`. Both accompany the separate model pack. No public Q5_K download URL is invented.

## Runtime findings

The pinned llama.cpp source `6783b11fb0889d68d0046176b4cc92ceee1961b0` contains an LFM2-MoE graph and indexed expert matrix multiplication. Architecture code in upstream does not establish support in the packaged runner:

- The 7120P balanced runtime's `driver/main.cpp`, SHA-256 `f4a0a2403f39cf5e1eef331ab8eab19f5169df6c2857011e2d6377ecd9e7774f`, explicitly allows only `lfm2` and `llama` after model load.
- Its `candidate/matmul.inc`, SHA-256 `6b895333610dd63a8de7d8750026396dbb7c7dcb37347c144f95541284ef5cbb`, requires dimension 2 and 3 to be 1. Packed expert tensors have a separate expert dimension; the dense optimized path is not evidence for `MUL_MAT_ID` performance.
- Generic Q5_K dot hooks exist, but expert dispatch, routing, recurrent state, correctness, cancellation and peak memory have not been qualified for this model. The existing native archive IDs/hashes remain unchanged.

The app recognizes `lfm2moe` catalog metadata but always rejects execution on these runtimes. Changing an availability flag, copying a GGUF, or adding a native-acceptance field cannot bypass that gate. No optimized badge or alternate host engine is selected.

## Resource accounting and import

The GGUF metadata reader now retains bounded numeric per-layer arrays. For this checkpoint's six attention blocks, eight KV heads per attention block and 64-dimensional keys/values, F16 KV uses 12,288 bytes per token. That is only the KV component. Routing, expert scratch, recurrent state and the entire GGUF's resident weight bytes must also be accounted for. Four active experts do not mean only four experts' weights need to be resident.

MoE metadata can be inspected, but automatic/manual allocation rejects it until a native memory profile is validated. A dense-model activation estimate is not reused.

Local model imports can contain any nonempty subset of this app's pinned model manifest. The single-model Gaston pack does not require the existing LFM/Llama files again. All selected source hashes and existing destination hashes are verified before copying. External pack metadata never supplies trusted hashes or execution permission. `Setup.ps1 -Mode AddModels -ModelIds <id>` optionally selects an exact already-pinned model.

Enabling chat still requires a separately identified KNC MoE runtime, validated for this model's graph, expert dispatch, numerical output, cancellation, resource allocation, thermal behavior and performance. This release does not change installed applications, card configuration or SSH trust.
