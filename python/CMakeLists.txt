# -------------------------------------------------
# Python + SWIG wrapper for OpenMMReaxFF
# -------------------------------------------------

# 1. Find dependencies (Do NOT use REQUIRED so we can gracefully disable)
find_package(Python3 COMPONENTS Interpreter Development NumPy)
find_package(SWIG 4.0)

if(NOT Python3_FOUND OR NOT SWIG_FOUND)
    message(STATUS "Python wrapper disabled because Python3 or SWIG was not found.")
    set(OPENMM_BUILD_PYTHON_WRAPPERS OFF CACHE BOOL "Build the Python API wrapper" FORCE)
    return() # Exit this CMakeLists.txt safely
endif()

# 2. Load SWIG macros
include(${SWIG_USE_FILE})

# 3. Define paths and names
set(OPENMM_SWIG_INCLUDE "${OPENMM_INCLUDE_DIR}/openmm" CACHE PATH "Where OpenMM's .i files live")
set(PLUGIN_INCLUDE_DIR  "${CMAKE_SOURCE_DIR}/openmmapi/include" CACHE PATH "ReaxFF plugin public headers")

set(SWIG_MODULE_NAME openmmReaxFF)
set(SWIG_INTERFACE   ${CMAKE_CURRENT_SOURCE_DIR}/src/reaxff.i)

# Let SWIG find both OpenMM's and our own headers
set(SWIG_INCLUDE_DIRS
    ${OPENMM_INCLUDE_DIR}
    ${PLUGIN_INCLUDE_DIR}
    ${Python3_INCLUDE_DIRS}
)

# 4. Configure SWIG source properties
set_property(SOURCE ${SWIG_INTERFACE} PROPERTY CPLUSPLUS ON)
set_property(SOURCE ${SWIG_INTERFACE} PROPERTY SWIG_FLAGS
    -I${OPENMM_SWIG_INCLUDE}
    -I${PLUGIN_INCLUDE_DIR}
    -modern
    -Wall
)

# 5. Add the library
swig_add_library(${SWIG_MODULE_NAME}
    LANGUAGE python
    TYPE MODULE
    SOURCES ${SWIG_INTERFACE})

# 6. Configure target
target_include_directories(${SWIG_MODULE_NAME} PRIVATE
    ${SWIG_INCLUDE_DIRS}
    ${CMAKE_SOURCE_DIR}/openmmapi/include
    ${CMAKE_SOURCE_DIR}/openmmapi/include/internal   # Required for windowsExportReaxff.h
    ${CMAKE_SOURCE_DIR}/reaxff_puremd/include
)

set_target_properties(${SWIG_MODULE_NAME} PROPERTIES
    OUTPUT_NAME _openmmReaxFF
    PREFIX ""
    INSTALL_RPATH "${OPENMM_LIB_DIR};${CMAKE_INSTALL_PREFIX}/lib"
    BUILD_RPATH   "${OPENMM_LIB_DIR}"
)

target_link_libraries(${SWIG_MODULE_NAME} PRIVATE
    ${SHARED_TARGET}            # OpenMMReaxFF shared lib
    ${OPENMM_LIBRARY}
    ${Python3_LIBRARIES}
)

if(OPENMM_BUILD_REAXFF_MPI)
    target_link_libraries(${SWIG_MODULE_NAME} PRIVATE OpenMP::OpenMP_CXX)
endif()

# 7. Install rules
set(PYTHON_INSTALL_DIR "${Python3_SITELIB}" CACHE PATH "Python module install directory")
if(NOT PYTHON_INSTALL_DIR OR PYTHON_INSTALL_DIR STREQUAL "")
    set(PYTHON_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/lib/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages")
endif()

install(TARGETS ${SWIG_MODULE_NAME}
        LIBRARY DESTINATION "${PYTHON_INSTALL_DIR}"
                PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                            GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

install(FILES
            ${CMAKE_CURRENT_BINARY_DIR}/${SWIG_MODULE_NAME}.py
        DESTINATION "${PYTHON_INSTALL_DIR}")

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/reaxff.py")
    install(FILES
                ${CMAKE_CURRENT_SOURCE_DIR}/reaxff.py
            DESTINATION "${PYTHON_INSTALL_DIR}")
endif()