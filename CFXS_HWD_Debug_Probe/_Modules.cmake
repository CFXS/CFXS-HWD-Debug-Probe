include(FetchContent)
set(FETCHCONTENT_QUIET FALSE)

# CFXS-Base
FetchContent_Declare(lib_CFXS_Base GIT_REPOSITORY https://github.com/CFXS/CFXS-Base.git GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_CFXS_Base)
target_link_libraries(${PROJECT_NAME} PUBLIC CFXS_Base)

# Tiva driverlib
FetchContent_Declare(lib_tm4c_driverlib GIT_REPOSITORY https://github.com/CFXS/tm4c-driverlib.git GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_tm4c_driverlib)
target_link_libraries(${PROJECT_NAME} PUBLIC tm4c_driverlib)

# CFXS-Platform
FetchContent_Declare(lib_CFXS_Platform GIT_REPOSITORY https://github.com/CFXS/CFXS-Platform.git GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_CFXS_Platform)
target_include_directories(CFXS_Platform PUBLIC "${lib_cfxs_base_SOURCE_DIR}/include")
target_include_directories(CFXS_Platform PUBLIC "${lib_tm4c_driverlib_SOURCE_DIR}")
target_link_libraries(${PROJECT_NAME} PUBLIC CFXS_Platform)

# CFXS-HW
FetchContent_Declare(lib_CFXS_Hardware GIT_REPOSITORY https://github.com/CFXS/CFXS-HW.git GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_CFXS_Hardware)
target_include_directories(CFXS_HW PUBLIC "${lib_cfxs_base_SOURCE_DIR}/include")
target_include_directories(CFXS_HW PUBLIC "${lib_cfxs_platform_SOURCE_DIR}/include")
target_include_directories(CFXS_HW PUBLIC "${lib_tm4c_driverlib_SOURCE_DIR}")
target_link_libraries(${PROJECT_NAME} PUBLIC CFXS_HW)

# CFXS-LLDS
FetchContent_Declare(lib_CFXS_LLDS GIT_REPOSITORY https://github.com/CFXS/CFXS-LLDS GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_CFXS_LLDS)
target_include_directories(CFXS_LLDS PUBLIC "${lib_cfxs_base_SOURCE_DIR}/include")
target_link_libraries(${PROJECT_NAME} PUBLIC CFXS_LLDS)

# SeggerRTT
FetchContent_Declare(lib_printf_impl_SeggerRTT GIT_REPOSITORY https://github.com/CFXS/SeggerRTT-printf.git GIT_SHALLOW TRUE GIT_TAG master)
FetchContent_MakeAvailable(lib_printf_impl_SeggerRTT)
target_link_libraries(${PROJECT_NAME} PUBLIC printf_impl_SeggerRTT)
