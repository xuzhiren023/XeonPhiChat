# File transfer in 1.6.9

Phi Chat first tries MPSS SCIF DMA for model weights, vision projectors, runtime archives and attached PNGs. Small scripts, the 22 KB receiver bootstrap and connection commands still use the existing pinned SSH connection. If SCIF is unavailable or a transfer fails, the app confirms receiver cleanup and retries through SCP. Stop, thermal/identity errors and uncertain cleanup never trigger a retry.

No new driver, compiler, Python installation or network adapter configuration is required. The Windows installer contains both transfer helpers; they use the MPSS driver already installed on Windows and the card's `libscif.so.0`. The Intel driver and SDK are not redistributed.

## Desktop slots and Thunderbolt enclosures

SCIF runs over PCIe. The card selected through authenticated SSH connects back to the host's dynamically allocated SCIF port. A per-transfer nonce binds that connection to the selected card. The sender enumerates SCIF nodes and verifies its peer; it does not assume that the selected card is node 1 or look for a Thunderbolt adapter. A directly attached motherboard card uses the same path.

Actual throughput depends on the negotiated PCIe link, storage and driver. SCIF removes SSH encryption and virtual-Ethernet processing from the bulk upload; it cannot raise the card's negotiated link speed or promise the enclosure's advertised Thunderbolt bandwidth. On the tested 7120P link (PCIe x4 at 5 GT/s), the 5.85 GB decoder transferred in 26.375 seconds, about 212 MiB/s. A matched 256 MiB + 129-byte end-to-end comparison measured 69.5 MiB/s for SCIF versus 13.6 MiB/s for SCP; short transfers include bootstrap/cleanup overhead. This is not full advertised Thunderbolt bandwidth.

## Transfer lifetime

The sender registers a reusable, page-aligned 64 MiB buffer. The receiver maps and registers successive windows of an exclusive `.part` file, and DMA writes directly into those file-backed pages. This bounds pinned memory and avoids another bulk copy on the Phi cores. File positions and sizes are 64-bit. Synchronous RMA completion precedes each window acknowledgement, and only the acknowledged, exact-length file is published by the app. There is no image/model SHA-256 scan during transfer.

Progress comes from the sender's local byte counter, so the DMA path does not start an SSH process every second. SCP fallback polls less frequently while retaining regular temperature and cancellation checks. SHA-256 checks at initial download and installer admission still establish the pinned local artifact identity.

The receiver checks the existing card workload token and the transfer nonce. It exits and removes an incomplete file on connection loss, controller EOF, or missed heartbeats. The app closes the receiver and confirms its exit before fallback. Partial data is never passed to inference as a complete model.

While sending a picture to a primed model, the host continues its resident-worker heartbeat and checks that response's Stop flag. Cancellation follows the existing stop/re-prime behavior and does not publish an unfinished picture request.

## Development and validation

`tools/scif-transfer/Build-Sender.ps1` builds the Windows x64 sender with the .NET Framework compiler. `tools/scif-transfer/build-receiver.sh` cross-builds the K1OM receiver with MPSS 3.8.6 GCC 5.1.1. Source and binary identities are recorded in `assets/scif-transfer-build.json`. The native library API comes from the installed MPSS SDK.

The Windows host suite uses mocks and frame tests. The receiver's Linux fixture links `tests/fake-scif.c`, simulating control messages and memory writes without a SCIF driver. Run that fixture only in an isolated Linux build VM without `/dev/scif`; it uses disposable `/root/knc-phase3-run-fixture-*` and `/tmp` paths. Neither fixture demonstrates PCIe DMA speed or driver compatibility on a real card.

Native 7120P checks passed for exact-byte readback across DMA windows, model/projector and PNG upload, cancellation cleanup, transport-failure SCP fallback and text/image inference. The receiver keeps its completion endpoint open until Windows consumes the acknowledgement, fixing a close race found on the real MPSS driver. Direct motherboard attachment, 3120A and physical unplug during transfer remain untested. See VALIDATION.md for measured scope. Do not run these checks while another application owns the card.
