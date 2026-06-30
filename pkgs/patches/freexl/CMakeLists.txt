cmake_minimum_required(VERSION 3.14)
project(freexl VERSION 2.0.0 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
find_package(PkgConfig REQUIRED)
find_package(Iconv REQUIRED)

option(FREEXL_ENABLE_XMLDOC "Enable XLSX/ODS support via expat and minizip" ON)

if(FREEXL_ENABLE_XMLDOC)
  pkg_check_modules(PC_MINIZIP REQUIRED minizip)
  find_library(MINIZIP_LIBRARY NAMES minizip HINTS ${PC_MINIZIP_LIBRARY_DIRS} REQUIRED)
  find_package(expat CONFIG REQUIRED)
endif()

# Generate config.h
set(VERSION "${PROJECT_VERSION}")
if(NOT FREEXL_ENABLE_XMLDOC)
  set(OMIT_XMLDOC 1)
endif()
configure_file(cmake/config.h.in config.h)
# On MSVC (incl. clang targeting the MSVC ABI) freexl.c includes
# "config-msvc.h" instead of "config.h"; generate it from the same template
# so the MSVC code path finds an equivalent, freshly-configured header.
configure_file(cmake/config.h.in config-msvc.h)

# Generate freexl.pc
if(NOT Iconv_IS_BUILT_IN)
  set(ICONV_LIBS "-liconv")
else()
  set(ICONV_LIBS "")
endif()

if(FREEXL_ENABLE_XMLDOC)
  set(XMLDOC_REQUIRES "expat minizip")
else()
  set(XMLDOC_REQUIRES "")
endif()

configure_file(cmake/freexl.pc.in freexl.pc @ONLY)

# For static libs, transitive deps must be PUBLIC so consumers link them
if(BUILD_SHARED_LIBS)
  set(_DEP_SCOPE PRIVATE)
else()
  set(_DEP_SCOPE PUBLIC)
endif()

# Library target
add_library(freexl
    src/freexl.c
)

if(FREEXL_ENABLE_XMLDOC)
  target_sources(freexl PRIVATE
        src/freexl_xlsx.c
        src/freexl_ods.c
    )
endif()

target_include_directories(freexl
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/headers>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_BINARY_DIR}
)

# Link dependencies
if(NOT WIN32)
  target_link_libraries(freexl ${_DEP_SCOPE} m)
endif()

if(NOT Iconv_IS_BUILT_IN)
  target_link_libraries(freexl ${_DEP_SCOPE} Iconv::Iconv)
endif()

if(FREEXL_ENABLE_XMLDOC)
  target_include_directories(freexl PRIVATE ${PC_MINIZIP_INCLUDE_DIRS})
  target_link_libraries(freexl ${_DEP_SCOPE}
        ${MINIZIP_LIBRARY}
        expat::expat
    )
endif()

# Windows shared library export
if(WIN32 AND BUILD_SHARED_LIBS)
  target_compile_definitions(freexl PRIVATE DLL_EXPORT)
endif()

set_target_properties(freexl PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    EXPORT_NAME freexl
)

# Install
install(TARGETS freexl
    EXPORT FreeXLTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES headers/freexl.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/freexl.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# CMake package config export
install(EXPORT FreeXLTargets
    FILE FreeXLTargets.cmake
    NAMESPACE FREEXL::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/FreeXL
)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfig.cmake.in [=[
@PACKAGE_INIT@
include(CMakeFindDependencyMacro)
find_dependency(Iconv)
if(@FREEXL_ENABLE_XMLDOC@)
  find_dependency(expat CONFIG)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/FreeXLTargets.cmake")
check_required_components(FreeXL)
]=])

configure_package_config_file(
    ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/FreeXL
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/FreeXLConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/FreeXL
)
