set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "vcpkg target triplet")

if(DEFINED ENV{VCPKG_ROOT} AND EXISTS "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
  set(_gemma_vcpkg_root "$ENV{VCPKG_ROOT}")
else()
  set(_gemma_vcpkg_root "C:/Program Files/Microsoft Visual Studio/18/Community/VC/vcpkg")
endif()

set(_gemma_vcpkg_toolchain "${_gemma_vcpkg_root}/scripts/buildsystems/vcpkg.cmake")
if(NOT EXISTS "${_gemma_vcpkg_toolchain}")
  message(FATAL_ERROR
    "vcpkg toolchain not found. Set VCPKG_ROOT or install vcpkg with Visual Studio 2026.")
endif()

include("${_gemma_vcpkg_toolchain}")
