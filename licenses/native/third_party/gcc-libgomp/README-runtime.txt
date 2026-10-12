GNU OpenMP runtime for Intel Knights Corner (K1OM)

This directory preserves the locally built libgomp.so.1.0.0, the corresponding
source files, GNU GPL v3 and GCC Runtime Library Exception, and build records. No source or generated-file linker patch was required.
The runtime was cross-compiled, linked, and identified as EM_K1OM=181. It was
NOT executed on a Xeon Phi card in this environment.

Provenance
- SDK: Intel MPSS 3.8.6, GNU GCC 5.1.1, patched GNU binutils 2.22.52.20120302.
- Public distribution: aidancrowther/k1om-compiler:latest.
- Builder description: https://www.aidancrowther.com/project/xeonphi
- Image manifest: sha256:2c84636b29c8b9a52c1421ca7a42313d1e017487216cccc8b014867920b3587c
- SDK layer: sha256:962344968202bd5d4cd4b8d089b05d3ec49d663508e8053a84700761bcd978fe
- Source layer: sha256:25ec6456c97f6c7a0fe70ab00f580f10e2fd8001ad5b8c0f80053e6305ad2983
Both downloaded layers were checked against their registry SHA256 digests.
Only compiler/sysroot/source files were extracted. No Docker daemon, host
MPSS driver, or coprocessor firmware was installed.

Runtime source: https://github.com/apc-llc/gcc-5.1.1-knc
Commit: af7cc04cef723da3166f0d6f1539f02525fe5a93
The commit was checked against the image's .git/refs/heads/master.
libgomp-source.tar.gz includes libgomp and the build helper/config/include
files needed for the standalone build, with COPYING3 and COPYING.RUNTIME.
The compiler binaries used were the original SDK binaries, not the image
builder's separate replacement compiler.

Compatibility entry points
/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-gcc and its g++ counterpart are shell
wrappers to the MPSS 3.8.6 GNU K1OM compilers. The directory name is a requested
compatibility path; the actual compiler version is 5.1.1, NOT 4.7. The -mknc
option is passed unchanged and enables __KNC__ and __k1om__, without AVX flags.

Build outline
1. Extract libgomp-source.tar.gz and make a sibling libgomp-build directory.
2. Configure libgomp with --build=x86_64-linux-gnu --host=k1om-mpss-linux
   --target=k1om-mpss-linux --disable-multilib --enable-shared --enable-static.
   Use the K1OM GCC/G++/ar/ranlib, CFLAGS='-O2 -mknc', prefix at the target
   sysroot's usr and libdir at the target sysroot's usr/lib64. The exact
   configure command is preserved in configure-command.txt, and
   build-libgomp.sh reproduces the standalone configure/build/install steps.
3. Run make -j4 libgomp.la LIBS='-lrt -ldl', then make
   install-toolexeclibLTLIBRARIES install-nodist_libsubincludeHEADERS
   install-nodist_toolexeclibHEADERS LIBS='-lrt -ldl'. Linking librt before
   libc makes clock_gettime and clock_getres require GLIBC_2.14 from librt,
   rather than GLIBC_2.17 from libc; verified with readelf --dyn-syms.
   This preserves the timing symbol versions expected by older MPSS cards.
   Install generated omp.h in the target sysroot's usr/include as well,
   because standalone configuration leaves GCC's private version field empty.
4. Link a C and C++ OpenMP probe with -O3 -mknc -fopenmp -ffast-math
   -funroll-loops. Both probes linked successfully as ET_EXEC/EM_K1OM binaries.
   Neither probe was run on the host or a coprocessor.

Runtime deployment
Programs built with -fopenmp need libgomp.so.1. Copy this libgomp.so.1.0.0 into
an application-private lib directory and provide a libgomp.so.1 symlink.
Point LD_LIBRARY_PATH at that private directory when running on the KNC card.
This runtime depends on the card's librt.so.1, libdl.so.2, libpthread.so.0,
and libc.so.6.
No Intel proprietary compiler runtime is required. Do not replace the card's
libc or loader with libraries from the build host.
