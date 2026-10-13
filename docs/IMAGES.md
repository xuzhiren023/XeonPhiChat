# Images and the multimodal runtime

Phi Chat 1.6.0 uses the `61e9799` runtime on 7120P for all eight catalog models. Step3-VL accepts pictures. Gaston LFM2-MoE and the existing LFM2/Llama models accept text. The 3120A retains its pinned `d57e0e6` text runtime; no fixed and qualified multimodal build was supplied for that card.

## Use

Import the extracted `PhiChat-1.6.0-Step3-Vision.zip` with **Add-Models.cmd**. Select **Step3-VL 10B Q5_K_M** in a new chat and click **Load model**. Load prepares the language weights and matching projector together. The first language download is about 5.9 GB; the vision pack is about 1.9 GB.

Click **+** or drop pictures into the window. Supported formats are PNG, JPEG and BMP, up to 32 MiB per source file. Larger dimensions are reduced to the runtime's 4096-pixel side limit. Images are copied into the app's session store; the original file is untouched. Click a thumbnail to see the full image or its **×** button to remove it before sending. An image without text sends “Describe this image.”

Follow-ups replay the retained image alongside its original turn. The runtime accepts four images across an invocation, including history. When that or the context capacity is exceeded, the app omits complete older turns and their corresponding image references together. The visible conversation remains intact. Deleting a conversation releases its unreferenced images after any active response stops. Card disconnect or a changed card boot expires saved conversations and their images.

## Runtime contract

The exact executable is SHA-256 `e3366b50052818a7cc223f57b7b69f55316e5cd93e3ca9b67b413a849b235d54`. Source HEAD `61e97998bf49c2d425563920b7e83e52b5ae57a6` requires the retained `metadata-fix.patch` (`49b6dda4…`); HEAD alone is insufficient. The patch includes the KNC-only `noinline` workaround for the GCC metadata-store miscompilation. See `assets/multimodal-runtime-build.json` and `tools/native-runner/multimodal`.

The adapter passes one `--image` file for each `<__media__>` marker, in prompt order, plus the exact matching `--mmproj`. It uses the Step3 checkpoint's ChatML template and thinking prefix. Text and image requests share the same card lease, thermal checks, memory guard, heartbeat and Stop path. Transient image files are removed from card jobs and Windows job staging on completion, cancellation or failure.

Automatic allocation includes the entire decoder file, the RAM-backed projector file, a separate projector tensor allocation, vision scratch, compressed/decoded pictures and the language KV/activation buffers. It never discounts inactive MoE expert weights. Native prompt counting receives the actual images and projector. For the specifically pinned Step3 adapter, mtmd uses normal positions (one position per expanded token) and causal decoder chunks, so its expanded token count also gives the position count. This rule must not be generalized to other vision architectures. The runtime enforces both context bounds again before decoding. Image encoding memory remains protected by the live worker guard, since count-only does not encode the pictures.

The Q6_K projector is generated from the pinned [F16 artifact](https://huggingface.co/JamePeng2023/Step3-VL-10B-GGUF/tree/f0bc308167bb03e463e10ba8dfaa4879092d0e84) using llama.cpp quantizer `23b0202a189c44a54625aadcb37a946dd1d6278d`, `Q6_K`, 8 threads. Some tensors remain floating point; “Q6_K” is the quantizer mode. Its complete SHA-256 is `b4d777752a55a73c8b518dd35b1c34e0bf2324a6d66059be3b7da3d5a89a7bc8`, size 1,893,755,040 bytes. Users import the finished pack; they need no converter or compiler.

The runtime handoff's numerical qualification used small synthetic image fixtures and trained TinyDolphin logits. Those results do not prove general visual accuracy or qualify every trained model. Current app hardware checks are documented in [VALIDATION.md](VALIDATION.md).

The older seanbailey projector has obsolete downsampler tensor names and cannot load with this runtime. The pinned JamePeng conversion uses the expected convolution names and F32 position embeddings. Requantizing the old file alone does not fix that mismatch.

The Q6_K conversion places 189 eligible matrices on the runtime's optimized K-quant paths. Its 475 F32 tensors and three F16 tensors retain position embeddings, normalization, biases and convolution weights. Q8 vision matrices use generic kernels in this build, so a Q8 projector is not the selected release artifact. Image encoding runs before token generation and is shown as **Processing images**; follow-ups containing retained pictures encode them again.

Vision is currently slow on the 7120P: the small color-image check took about eight minutes to its first response text, then generated at about 1.18 tokens/s. The runtime still has generic attention/convolution work. The app stays responsive and Stop can interrupt image processing.
