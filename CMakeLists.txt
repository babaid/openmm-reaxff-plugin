cmake_minimum_required(VERSION 3.17)

project(OpenMMReaxFF LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

#---------------------------------------------------
# Locate an installed OpenMM
#---------------------------------------------------
find_package(OpenMM CONFIG QUIET)
if(OpenMM_FOUND AND TARGET OpenMM::OpenMM)
    set(OPENMM_LIBRARY OpenMM::OpenMM)
    set(OPENMM_LIBRARY_STATIC OpenMM::OpenMM)
    set(OPENMM_INCLUDE_DIR "${OpenMM_INCLUDE_DIRS}")
    set(OPENMM_LIB_DIR "${OpenMM_LIBRARY_DIRS}")
else()
    find_path(OPENMM_DIR NAMES include/OpenMM.h
        HINTS "$ENV{OPENMM_DIR}" "$ENV{OPENMM_HOME}" "$ENV{CONDA_PREFIX}"
        PATHS /usr/local/openmm /usr/local /opt/openmm)

    if(NOT OPENMM_DIR)
        message(FATAL_ERROR "OpenMM was not found. Install OpenMM or set OPENMM_DIR/OPENMM_HOME/CONDA_PREFIX to the OpenMM installation prefix.")
    endif()

    set(OPENMM_INCLUDE_DIR "${OPENMM_DIR}/include" CACHE PATH "OpenMM headers")
    set(OPENMM_LIB_DIR     "${OPENMM_DIR}/lib"     CACHE PATH "OpenMM libraries")

    if(NOT EXISTS "${OPENMM_INCLUDE_DIR}/OpenMM.h")
        find_path(OPENMM_INCLUDE_DIR_HINT NAMES OpenMM.h
            HINTS "${OPENMM_DIR}" "${OPENMM_DIR}/include" "${OPENMM_DIR}/include/openmm"
            PATH_SUFFIXES include include/openmm)
        if(OPENMM_INCLUDE_DIR_HINT)
            set(OPENMM_INCLUDE_DIR "${OPENMM_INCLUDE_DIR_HINT}" CACHE PATH "OpenMM headers" FORCE)
        endif()
    endif()

    if(EXISTS "${OPENMM_DIR}/include/openmm" AND NOT EXISTS "${OPENMM_INCLUDE_DIR}/OpenMM.h")
        set(OPENMM_INCLUDE_DIR "${OPENMM_DIR}/include" CACHE PATH "OpenMM headers" FORCE)
    endif()

    if(NOT EXISTS "${OPENMM_LIB_DIR}/libOpenMM.so" AND NOT EXISTS "${OPENMM_LIB_DIR}/OpenMM.lib")
        find_path(OPENMM_LIB_DIR_HINT NAMES libOpenMM.so libOpenMM.dylib OpenMM.lib
            HINTS "${OPENMM_DIR}" "${OPENMM_DIR}/lib" "${OPENMM_DIR}/lib64"
            PATH_SUFFIXES lib lib64)
        if(OPENMM_LIB_DIR_HINT)
            set(OPENMM_LIB_DIR "${OPENMM_LIB_DIR_HINT}" CACHE PATH "OpenMM libraries" FORCE)
        endif()
    endif()

    if(EXISTS "${OPENMM_DIR}/lib/libOpenMM.so")
        set(OPENMM_LIB_DIR "${OPENMM_DIR}/lib" CACHE PATH "OpenMM libraries" FORCE)
    elseif(EXISTS "${OPENMM_DIR}/lib64/libOpenMM.so")
        set(OPENMM_LIB_DIR "${OPENMM_DIR}/lib64" CACHE PATH "OpenMM libraries" FORCE)
    endif()

    if(NOT EXISTS "${OPENMM_INCLUDE_DIR}/OpenMM.h")
        if(DEFINED ENV{CONDA_PREFIX} AND EXISTS "$ENV{CONDA_PREFIX}/include/OpenMM.h")
            set(OPENMM_INCLUDE_DIR "$ENV{CONDA_PREFIX}/include" CACHE PATH "OpenMM headers" FORCE)
            set(OPENMM_LIB_DIR "$ENV{CONDA_PREFIX}/lib" CACHE PATH "OpenMM libraries" FORCE)
        else()
            message(FATAL_ERROR "OpenMM headers were not found in ${OPENMM_INCLUDE_DIR}. Check your OPENMM_DIR/CONDA_PREFIX.")
        endif()
    endif()

    find_library(OPENMM_LIBRARY NAMES OpenMM OpenMM_static PATHS "${OPENMM_LIB_DIR}" "${OPENMM_DIR}/lib64" REQUIRED)
    find_library(OPENMM_LIBRARY_STATIC NAMES OpenMM_static OpenMM PATHS "${OPENMM_LIB_DIR}" "${OPENMM_DIR}/lib64")
endif()

include_directories("${OPENMM_INCLUDE_DIR}")
link_directories("${OPENMM_LIB_DIR}")

set(_requested_install_prefix "")
if(DEFINED CMAKE_INSTALL_DIR AND NOT "${CMAKE_INSTALL_DIR}" STREQUAL "")
    set(_requested_install_prefix "${CMAKE_INSTALL_DIR}")
elseif(DEFINED CMAKE_INSTALL_PREFIX AND NOT "${CMAKE_INSTALL_PREFIX}" STREQUAL "")
    set(_requested_install_prefix "${CMAKE_INSTALL_PREFIX}")
endif()

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT OR DEFINED CMAKE_INSTALL_DIR)
    if(_requested_install_prefix)
        set(CMAKE_INSTALL_PREFIX "${_requested_install_prefix}" CACHE PATH "Install location" FORCE)
    elseif(DEFINED ENV{CONDA_PREFIX} AND EXISTS "$ENV{CONDA_PREFIX}")
        set(CMAKE_INSTALL_PREFIX "$ENV{CONDA_PREFIX}" CACHE PATH "Install location" FORCE)
    else()
        set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Install location" FORCE)
    endif()
endif()

if(DEFINED ENV{CONDA_PREFIX} AND EXISTS "$ENV{CONDA_PREFIX}")
    set(CMAKE_INSTALL_PREFIX "$ENV{CONDA_PREFIX}" CACHE PATH "Install location" FORCE)
endif()

#---------------------------------------------------
# Build options (previously inherited from OpenMM's own top-level build)
#---------------------------------------------------
option(OPENMM_BUILD_SHARED_LIB      "Build shared plugin library" ON)
option(OPENMM_BUILD_STATIC_LIB      "Build static plugin library" OFF)
option(OPENMM_BUILD_REAXFF_MPI      "Enable OpenMP in the ReaxFF plugin" ON)
option(OPENMM_BUILD_PYTHON_WRAPPERS "Build the Python API wrapper" ON)
option(BUILD_TESTING                "Build C++ test suite" ON)

find_package(Threads REQUIRED)
set(PTHREADS_LIB Threads::Threads)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|i.86")
    set(X86 TRUE)
endif()

if(OPENMM_BUILD_REAXFF_MPI)
    find_package(OpenMP REQUIRED)
endif()

#---------------------------------------------------
# Plugin sources
#---------------------------------------------------
SET(OPENMM_SOURCE_SUBDIRS openmmapi)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/serialization/include" AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/serialization/src")
    list(APPEND OPENMM_SOURCE_SUBDIRS serialization)
endif()

SET(OPENMMREAXFF_LIBRARY_NAME OpenMMReaxFF)
ADD_DEFINITIONS(-DOPENMM_REAXFF_LIBRARY_NAME=${OPENMMREAXFF_LIBRARY_NAME})
SET(SHARED_TARGET ${OPENMMREAXFF_LIBRARY_NAME})
SET(STATIC_TARGET ${OPENMMREAXFF_LIBRARY_NAME}_static)

SET(API_INCLUDE_DIRS)
FOREACH(subdir ${OPENMM_SOURCE_SUBDIRS})
    SET(API_INCLUDE_DIRS ${API_INCLUDE_DIRS}
                         ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/include
                         ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/include/internal)
ENDFOREACH()

SET(API_INCLUDE_FILES)
FOREACH(dir ${API_INCLUDE_DIRS})
    FILE(GLOB fullpaths ${dir}/*.h)
    SET(API_INCLUDE_FILES ${API_INCLUDE_FILES} ${fullpaths})
ENDFOREACH()

SET(SOURCE_FILES)
SET(SOURCE_INCLUDE_FILES)
FOREACH(subdir ${OPENMM_SOURCE_SUBDIRS})
    FILE(GLOB_RECURSE src_files ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/src/*.cpp
                                 ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/src/*.c)
    FILE(GLOB incl_files ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/src/*.h)
    SET(SOURCE_FILES         ${SOURCE_FILES}         ${src_files})
    SET(SOURCE_INCLUDE_FILES ${SOURCE_INCLUDE_FILES} ${incl_files})
    INCLUDE_DIRECTORIES(BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/${subdir}/include)
ENDFOREACH()

IF(NOT MSVC AND X86)
    SET_SOURCE_FILES_PROPERTIES(${SOURCE_FILES} PROPERTIES COMPILE_FLAGS "-msse4.1")
ENDIF()

ADD_SUBDIRECTORY("${CMAKE_CURRENT_SOURCE_DIR}/3rdParty/sPuReMD")
set(SPUREMD_LINK_TARGET puremd)

#---------------------------------------------------
# Targets
#---------------------------------------------------
IF(OPENMM_BUILD_SHARED_LIB)
    ADD_LIBRARY(${SHARED_TARGET} SHARED ${SOURCE_FILES} ${SOURCE_INCLUDE_FILES} ${API_INCLUDE_FILES})

    TARGET_LINK_LIBRARIES(${SHARED_TARGET} PUBLIC ${OPENMM_LIBRARY} ${PTHREADS_LIB})
    TARGET_LINK_LIBRARIES(${SHARED_TARGET} PRIVATE ${SPUREMD_LINK_TARGET})

    if(OPENMM_BUILD_REAXFF_MPI)
        TARGET_LINK_LIBRARIES(${SHARED_TARGET} PUBLIC OpenMP::OpenMP_CXX)
    endif()

    SET_TARGET_PROPERTIES(${SHARED_TARGET} PROPERTIES
        LINKER_LANGUAGE CXX
        COMPILE_FLAGS "-DOPENMM_REAXFF_BUILDING_SHARED_LIBRARY")
    install(TARGETS ${SHARED_TARGET} LIBRARY DESTINATION lib/plugins)
    install(TARGETS ${SHARED_TARGET} LIBRARY DESTINATION lib)
ENDIF()

IF(OPENMM_BUILD_STATIC_LIB)
    ADD_LIBRARY(${STATIC_TARGET} STATIC ${SOURCE_FILES} ${SOURCE_INCLUDE_FILES} ${API_INCLUDE_FILES})
    # Changed ${SPUREMD_LIBRARY} to ${SPUREMD_LINK_TARGET}
    TARGET_LINK_LIBRARIES(${STATIC_TARGET} ${OPENMM_LIBRARY_STATIC} ${PTHREADS_LIB} ${SPUREMD_LINK_TARGET})
    if(OPENMM_BUILD_REAXFF_MPI)
        TARGET_LINK_LIBRARIES(${STATIC_TARGET} OpenMP::OpenMP_CXX)
    endif()
    SET_TARGET_PROPERTIES(${STATIC_TARGET} PROPERTIES
        LINKER_LANGUAGE CXX
        COMPILE_FLAGS "-DOPENMM_REAXFF_BUILDING_STATIC_LIBRARY")
    install(TARGETS ${STATIC_TARGET} ARCHIVE DESTINATION lib)
ENDIF()

#---------------------------------------------------
# Public headers
#---------------------------------------------------
FILE(GLOB TOP_HEADERS      openmmapi/include/openmm/*.h)
FILE(GLOB INTERNAL_HEADERS openmmapi/include/openmm/internal/*.h)
install(FILES ${TOP_HEADERS}      DESTINATION include/openmm)
install(FILES ${INTERNAL_HEADERS} DESTINATION include/openmm/internal)

#---------------------------------------------------
# Python + tests
#---------------------------------------------------
IF(OPENMM_BUILD_PYTHON_WRAPPERS)
    ADD_SUBDIRECTORY(python)
ENDIF()

IF(BUILD_TESTING)
    ADD_SUBDIRECTORY(tests)
ENDIF()