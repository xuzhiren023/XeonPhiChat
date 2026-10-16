# Included from arch/knc/knc.cmake, in the same scope as GGML_CPU_SOURCES.
# knc-mq-panel8.c is installed as knc-mq.c: retain decode3's source-specific
# strict math, O3/unrolling/stringop flags. Do not compile both implementations.
list(APPEND GGML_CPU_SOURCES ${knc}/dense.S ${knc}/panel8.S)
set_source_files_properties(${knc}/dense.S ${knc}/panel8.S PROPERTIES
    COMPILE_DEFINITIONS __KNC__)
# dense.inc and matmul-panel8.inc are included by the replaced ggml-cpu.c.
# This belongs to the backend source list, not the runner executable: static
# libraries otherwise leave unresolved kernel symbols or omit the dispatch.

list(APPEND GGML_CPU_SOURCES ${knc}/tile.S ${knc}/panel16.S ${knc}/wide.S ${knc}/pair-sum.S)
set_source_files_properties(${knc}/tile.S ${knc}/panel16.S ${knc}/wide.S ${knc}/pair-sum.S PROPERTIES COMPILE_DEFINITIONS __KNC__)
