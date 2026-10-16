# Thinking depth

Thinking models show **Thinking: Standard** below the message box. Choose **Light**, **Standard** or **Extended** before sending. The choice belongs to the current chat, survives navigation and reopening during the same card session, and applies to the next response without reloading the model. It is disabled while a response is running.

- **Light** requests brief reasoning focused on essential steps.
- **Standard** uses the model's original prompt behavior.
- **Extended** requests more deliberate reasoning and a check of the conclusion.

The pinned KNC runner has no native reasoning-effort parameter. Light and Extended add a short system instruction; they are model-guided preferences, not enforced thinking-token budgets. Actual reasoning length and latency depend on the question and checkpoint. Output length, batch size and context retain automatic allocation. The app does not implement PaCoRe, parallel rollouts, or a claimed ChatGPT-equivalent compute setting.

This selector is enabled for Huihui Step3-VL, both LFM2.5-2.6B quantizations, and LFM2.5-8B-A1B Gaston. It is hidden for the Llama, TinyDolphin and LFM2.5-VL checkpoints. An Off option is not offered for these always-thinking checkpoints. Only model-emitted reasoning is displayed in the collapsible thinking area.

Checkpoint references: [Step3-VL](https://huggingface.co/stepfun-ai/Step3-VL-10B), [Huihui Step3](https://huggingface.co/huihui-ai/Huihui-Step3-VL-10B-abliterated/tree/82c3e704ed330acfcc37a1b01b5fde548ca29679), [LFM2.5-2.6B](https://huggingface.co/LiquidAI/LFM2.5-2.6B), and [LFM2.5-8B-A1B](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B). Native smoke checks and their limits are recorded in [validation](VALIDATION.md).
