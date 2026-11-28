cmake_minimum_required(VERSION 3.5.0)
project(pow_solver)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

add_library(pow_solver SHARED pow_solver.cpp)
target_compile_features(pow_solver PRIVATE cxx_std_17)
target_compile_options(pow_solver PRIVATE -O3)
target_link_libraries(pow_solver PUBLIC libace_napi.z.so)
