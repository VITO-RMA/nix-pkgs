find_library(XercesC_LIBRARY NAMES xerces-c
             HINTS "${CMAKE_CURRENT_LIST_DIR}/../../../")
find_path(XercesC_INCLUDE_DIR NAMES xercesc/util/XercesVersion.hpp
          HINTS "${CMAKE_CURRENT_LIST_DIR}/../../../include")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(XercesC
    REQUIRED_VARS XercesC_LIBRARY XercesC_INCLUDE_DIR)

if(XercesC_FOUND AND NOT TARGET XercesC::XercesC)
    add_library(XercesC::XercesC UNKNOWN IMPORTED)
    set_target_properties(XercesC::XercesC PROPERTIES
        IMPORTED_LOCATION "${XercesC_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${XercesC_INCLUDE_DIR}")

    # Static xerces-c needs ICU (transcoder) and pthreads on the link line.
    get_filename_component(_xc_ext "${XercesC_LIBRARY}" EXT)
    if(_xc_ext STREQUAL ".a")
        include(CMakeFindDependencyMacro)
        find_package(Threads)
        find_dependency(ICU COMPONENTS uc data)
        if(ICU_FOUND)
            set_property(TARGET XercesC::XercesC APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES ICU::uc ICU::data)
        endif()
        if(Threads_FOUND)
            set_property(TARGET XercesC::XercesC APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES Threads::Threads)
        endif()
    endif()
endif()
