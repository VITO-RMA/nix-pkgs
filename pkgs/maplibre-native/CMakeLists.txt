cmake_minimum_required(VERSION 3.25)
project(MapLibreNativePackage LANGUAGES C CXX)

include(GNUInstallDirs)

get_filename_component(maplibre_source "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
add_subdirectory("${maplibre_source}" maplibre)

set_target_properties(mbgl-core PROPERTIES EXPORT_NAME Core)
target_compile_features(mbgl-core PUBLIC cxx_std_20)
# Upstream places target names inside conditional generator expressions. Mark
# them explicitly so CMake rewrites them to namespaced installed targets rather
# than emitting bare -lmbgl-* flags in downstream consumers.
get_target_property(core_link_libraries mbgl-core INTERFACE_LINK_LIBRARIES)
foreach(target mbgl-vendor-csscolorparser mbgl-freetype mbgl-harfbuzz mbgl-vendor-metal-cpp mbgl-vendor-icu)
    if(TARGET "${target}")
        string(REPLACE "${target}" "$<TARGET_NAME:${target}>" core_link_libraries "${core_link_libraries}")
    endif()
endforeach()
set_property(TARGET mbgl-core PROPERTY INTERFACE_LINK_LIBRARIES "${core_link_libraries}")
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
if(NOT MLN_WITH_CORE_ONLY)
    foreach(target mbgl-vendor-nunicode mbgl-vendor-sqlite mbgl-vendor-icu)
        if(TARGET "${target}")
            list(APPEND targets "${target}")
        endif()
    endforeach()
endif()
if(MLN_WITH_VULKAN)
    list(APPEND targets mbgl-vendor-vulkan-headers mbgl-vendor-VulkanMemoryAllocator
        glslang SPIRV glslang-default-resource-limits MachineIndependent OSDependent GenericCodeGen)
endif()
list(REMOVE_DUPLICATES targets)
foreach(target IN LISTS targets)
    install_maplibre_target("${target}")
endforeach()
install(EXPORT MapLibreNativeTargets NAMESPACE MapLibreNative::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/MapLibreNative")
set(dependencies "find_dependency(Threads)\n")
if(NOT MLN_WITH_CORE_ONLY AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
    string(APPEND dependencies "find_dependency(PNG)\n")
    if(MLN_WITH_EGL)
        string(APPEND dependencies "find_dependency(OpenGL COMPONENTS EGL)\n")
    endif()
endif()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/MapLibreNativeConfig.cmake"
    "include(CMakeFindDependencyMacro)\n${dependencies}include(\"\${CMAKE_CURRENT_LIST_DIR}/MapLibreNativeTargets.cmake\")\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/MapLibreNativeConfig.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/MapLibreNative")
install(FILES "${maplibre_source}/LICENSE.md"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/licenses/maplibre-native")
