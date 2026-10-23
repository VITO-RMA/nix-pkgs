cmake_minimum_required(VERSION 3.25)
project(MapLibreNativePackage LANGUAGES C CXX)

include(GNUInstallDirs)

get_filename_component(maplibre_source "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
add_subdirectory("${maplibre_source}" maplibre)

set_target_properties(mbgl-core PROPERTIES EXPORT_NAME Core)
target_compile_features(mbgl-core PUBLIC cxx_std_20)
# Public backend headers also depend on headers in upstream's source tree
# (for example, mln/gfx/offscreen_texture.hpp).
target_include_directories(mbgl-core PUBLIC "$<BUILD_INTERFACE:${maplibre_source}/src>")
find_package(Threads REQUIRED)
target_link_libraries(mbgl-core PUBLIC Threads::Threads ${CMAKE_DL_LIBS})
if(MLN_WITH_WEBGPU)
    # Public backend headers include WebGPU headers and the generated C++ shim.
    target_link_libraries(mbgl-core PUBLIC mbgl-vendor-wgpu)
endif()
if(MLN_WITH_METAL)
    target_link_libraries(mbgl-core PUBLIC mbgl-vendor-metal-cpp
        "-framework Foundation" "-framework QuartzCore")
endif()

function(install_maplibre_target target)
    # Preserve upstream's include layout and transitive dependencies while
    # making the installed CMake targets independent of the build tree.
    foreach(property INTERFACE_INCLUDE_DIRECTORIES INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
        get_target_property(directories "${target}" "${property}")
        if(NOT directories)
            continue()
        endif()
        set(relocated)
        foreach(include IN LISTS directories)
            if(include MATCHES "^\\$<BUILD_INTERFACE:(.*)>$")
                set(include "${CMAKE_MATCH_1}")
            elseif(include MATCHES "^\\$<INSTALL_INTERFACE:")
                continue()
            endif()
            if(include MATCHES "^${CMAKE_BINARY_DIR}/")
                file(RELATIVE_PATH relative "${CMAKE_BINARY_DIR}" "${include}")
                set(destination "${CMAKE_INSTALL_INCLUDEDIR}/maplibre-native/build/${relative}")
            elseif(include MATCHES "^${maplibre_source}/")
                file(RELATIVE_PATH relative "${maplibre_source}" "${include}")
                set(destination "${CMAKE_INSTALL_INCLUDEDIR}/maplibre-native/${relative}")
            else()
                list(APPEND relocated "${include}")
                continue()
            endif()
            list(APPEND relocated "$<BUILD_INTERFACE:${include}>" "$<INSTALL_INTERFACE:${destination}>")
            install(DIRECTORY "${include}/" DESTINATION "${destination}"
                FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp" PATTERN "*.hxx" PATTERN "*.inc")
        endforeach()
        set_property(TARGET "${target}" PROPERTY "${property}" "${relocated}")
    endforeach()
    install(TARGETS "${target}" EXPORT MapLibreNativeTargets
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endfunction()

# Reuse upstream's core export set rather than installing optional vendor test
# and benchmark targets. Vulkan and MLT have additional transitive archives.
get_directory_property(targets DIRECTORY "${maplibre_source}" DEFINITION EXPORT_TARGETS)
list(APPEND targets fastpfor-lib)
if(MLN_WITH_VULKAN)
    list(APPEND targets mbgl-vendor-vulkan-headers mbgl-vendor-VulkanMemoryAllocator
        glslang SPIRV glslang-default-resource-limits MachineIndependent OSDependent GenericCodeGen)
endif()
foreach(target IN LISTS targets)
    install_maplibre_target("${target}")
endforeach()
install(EXPORT MapLibreNativeTargets NAMESPACE MapLibreNative::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/MapLibreNative")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/MapLibreNativeConfig.cmake"
    "include(CMakeFindDependencyMacro)\nfind_dependency(Threads)\ninclude(\"\${CMAKE_CURRENT_LIST_DIR}/MapLibreNativeTargets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/MapLibreNativeConfig.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/MapLibreNative")
install(FILES "${maplibre_source}/LICENSE.md"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/maplibre-native")
