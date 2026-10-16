if (GGML_KNC AND LLAMA_KNC_TESTS)
    foreach(pair IN ITEMS
            "test-knc-context-dense|test-dense.cpp"
            "test-conversation-native|test-native-conversation.cpp"
            "test-knc-trained-image|test-trained-image.cpp"
            "bench-knc-context-dense|bench-dense.cpp"
            "test-knc-prefix|test-prefix.cpp"
            "test-knc-tiles|test-tiles.cpp"
            "test-knc-tasks|test-tasks.cpp")
        string(REPLACE "|" ";" fields "${pair}")
        list(GET fields 0 name)
        list(GET fields 1 file)
        add_executable(${name} ${file})
        target_compile_features(${name} PRIVATE cxx_std_14)
        # Prefix checks use assert(); Release's -DNDEBUG must not erase them.
        target_compile_options(${name} PRIVATE -UNDEBUG)
        target_include_directories(${name} PRIVATE ../../ggml/src ../../ggml/src/ggml-cpu/arch/knc)
        target_compile_definitions(${name} PRIVATE PHI_KNC_KERNELS PHI_PROFILE="${GGML_KNC_PROFILE}")
        target_link_libraries(${name} PRIVATE llama mtmd vendor::stb)
        if (TARGET OpenMP::OpenMP_CXX)
            target_link_libraries(${name} PRIVATE OpenMP::OpenMP_CXX)
        endif()
        set_target_properties(${name} PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "$ORIGIN/../lib")
    endforeach()
    # The inherited quantization checks also use assert(). Keep checks active
    # in Release builds instead of reporting a binary with erased assertions.
    foreach(name IN ITEMS test-knc-mq test-knc-dot test-knc-mtmd)
        if (TARGET ${name})
            target_compile_options(${name} PRIVATE -UNDEBUG)
        endif()
    endforeach()
endif()
