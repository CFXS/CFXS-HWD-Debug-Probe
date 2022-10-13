# Target
add_compile_definitions("PART_TM4C1294NCPDT")
add_compile_definitions("TARGET_IS_TM4C129_RA2")
add_compile_definitions("CFXS_PLATFORM_TM4C")
add_compile_definitions("CFXS_DEVICE_CLASS_TM4C129X")
add_compile_definitions("CFXS_CPU_CLOCK_FREQUENCY=120000000")

set(CFXS_STARTUP_PLATFORM "TM4C129X") # this is for startup file selection

# Project
add_compile_definitions("CFXS_PROJECT_NAME=\"CFXS HWD Debug Probe\"")
add_compile_definitions("CFXS_PROJECT_VERSION_STRING=\"1.0.0-dev\"")

add_compile_definitions(
    "SEGGER_DONT_REDEFINE_PRINTF" # custom printf lib, dont let segger redirect directly
    "SEGGER_RTT_MODE_DEFAULT=SEGGER_RTT_MODE_NO_BLOCK_SKIP"
    #"SEGGER_RTT_MODE_DEFAULT=SEGGER_RTT_MODE_BLOCK_IF_FIFO_FULL"
    "CFXS_DEBUG_TERMINAL_USE_COLORS=1"

    # Task Groups
    "LOW_PRIORITY=0"
    "HIGH_PRIORITY=1"
    "SYSTEM_PRIORITY=2"
) 

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    add_compile_definitions("DEBUG")
    add_compile_definitions("CFXS_DEBUG")
    add_compile_definitions("CFXS_DEBUG_ASSERT")
    add_compile_definitions("EASTL_ASSERT_ENABLED=1")
endif()
    
if("${CMAKE_BUILD_TYPE}" STREQUAL "Release")
    add_compile_definitions("RELEASE")
    add_compile_definitions("NDEBUG")
    add_compile_definitions("CFXS_DEBUG_ASSERT") # CFXS_ASSERT/CFXS_ERROR
endif()