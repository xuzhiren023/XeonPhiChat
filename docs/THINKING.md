# Thinking depth

Thinking models show **Thinking: Standard** below the message box. Choose **Light**, **Standard** or **Extended** before sending. The choice belongs to the current chat, survives navigation and reopening during the same card session, and applies to the next response without reloading the model. It is disabled while a response is running.

- **Light** requests brief reasoning focused on essential steps.
- **Standard** uses the model's original prompt behavior.
- **Extended** requests more deliberate reasoning and a check of the conclusion.

The pinned KNC runner has no native reasoning-effort parameter. Light and Extended add a short system instruction; they are model-guided preferences, not enforced thinking-token budgets. Actual reasoning length and latency depend on the question and checkpoint. Output length, batch size and context retain automatic allocation. The app does not implement PaCoRe, parallel rollouts, or a claimed ChatGPT-equivalent compute setting.

The control can change the response without consistently ordering its length or speed. Light is not guaranteed faster than Standard, and Extended is not guaranteed to produce more reasoning or a more accurate answer. The tooltip now makes the model's discretion explicit. Standard retains the unchanged original prompt.

This selector is enabled for Huihui Step3-VL, both LFM2.5-2.6B quantizations, and LFM2.5-8B-A1B Gaston. It is hidden for the Llama, TinyDolphin and LFM2.5-VL checkpoints. An Off option is not offered for these always-thinking checkpoints. Only model-emitted reasoning is displayed in the collapsible thinking area.

Checkpoint references: [Step3-VL](https://huggingface.co/stepfun-ai/Step3-VL-10B), [Huihui Step3](https://huggingface.co/huihui-ai/Huihui-Step3-VL-10B-abliterated/tree/82c3e704ed330acfcc37a1b01b5fde548ca29679), [LFM2.5-2.6B](https://huggingface.co/LiquidAI/LFM2.5-2.6B), and [LFM2.5-8B-A1B](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B). Native smoke checks and their limits are recorded in [validation](VALIDATION.md).

## 1.6.11 measurements

The controls were exercised through the installed resident app backend on 7120P, with greedy sampling, unchanged model templates and automatic context/output allocation. Each request began an independent conversation; preferences changed without reloading the model. The two questions were 17 multiplied by 23, and the bat-and-ball problem ($1.10 total, bat costs $1 more). Both asked for an answer plus one explanatory sentence. Preference order was Light/Standard/Extended for multiplication and Extended/Light/Standard for the price question.

Each cell shows **all generated tokens / backend response time**. Tokens include model-emitted reasoning and the final answer; time includes prompt processing. These are complete-answer behavior checks, not repeated statistical performance or broad accuracy benchmarks.

| Model and question | Light | Standard | Extended |
|---|---:|---:|---:|
| LFM2.5-2.6B Q5_K_M — multiply | 99 / 24.45 s | 124 / 25.89 s | 144 / 32.05 s |
| LFM2.5-2.6B Q5_K_M — price | 286 / 59.73 s | 264 / 52.62 s | 315 / 64.67 s |
| Huihui Step3-VL Q5_K_M — multiply | 237 / 106.87 s | 372 / 154.89 s | 581 / 252.15 s |
| Huihui Step3-VL Q5_K_M — price | 290 / 130.84 s | 478 / 205.54 s | 390 / 167.20 s |

All six LFM answers reached a final answer and were correct. On the price question, the reasoning section contained 729/710/635 characters for Light/Standard/Extended, respectively. Extended instead added more explanation to the final answer. Higher total output therefore does not establish deeper reasoning; even reasoning length was not ordered by the selector. The extra instruction also adds input processing, so Light can take longer than Standard.

LFM used decode3 with automatic context 131,072 and 120/240 generation/prompt workers. Other quantizations and Gaston did not receive a new native preference comparison in this release; their existing prompt routing remains covered by host tests.

All six Step3 answers also reached a correct final answer. Reasoning-section lengths were 525/868/1690 characters for multiplication and 588/1239/919 for the price question, in Light/Standard/Extended order. Multiplication followed the requested order, but Standard produced more reasoning and took longer than Extended on the price question. These examples show that the instruction can materially change emitted reasoning and latency; they do not establish a general accuracy benefit or a reliable compute budget. Step3 used R4 with automatic context 2,080, batch 16 and 180/240 workers. Its thinking runs peaked at 77 C.
