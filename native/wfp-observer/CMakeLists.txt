cmake_minimum_required(VERSION 3.24)
project(flydpi_wfp_observer LANGUAGES CXX)

add_library(flydpi_wfp_observer SHARED
    wfp_observer.cpp
)

target_compile_features(flydpi_wfp_observer PRIVATE cxx_std_20)
target_include_directories(flydpi_wfp_observer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(flydpi_wfp_observer PRIVATE Fwpuclnt Rpcrt4 Ws2_32)
target_compile_definitions(flydpi_wfp_observer PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
