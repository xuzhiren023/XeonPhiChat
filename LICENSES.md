# Licensing and provenance

The original repository did not supply a project-wide license for the first-party Phi Chat application. This migration does not assign a new license on the owner's behalf. Retained third-party license texts apply to their respective components, not automatically to the entire application.

The native runtime retains the GNU IMCI kernel package's [license](licenses/native/LICENSE), [third-party notices](licenses/native/THIRD-PARTY-NOTICES.txt), and GCC libgomp [GPLv3 text](licenses/native/third_party/gcc-libgomp/COPYING3) and [runtime exception](licenses/native/third_party/gcc-libgomp/COPYING.RUNTIME). Check those notices for component source provenance.

The d57e0e6 rebase also retains the fork's [llama.cpp MIT license](licenses/llama.cpp/LICENSE) and [KNC kernel license](licenses/llama.cpp/KNC-LICENSE). Exact source, driver and binary provenance is recorded in `assets/upstream-runtime-build.json`. The multimodal build also retains the [stb_image MIT notice](licenses/llama.cpp/STB-IMAGE-LICENSE.txt); its additional source/patch identities are in `assets/multimodal-runtime-build.json`.

Intel MPSS and Windows/OpenSSH system tools are supplied by the user's installed driver/Windows features. They are not copied from the developer PC into this release. Model weights are separate assets governed by upstream model licenses; see `docs/MODELS.md` and the pinned profiles.

