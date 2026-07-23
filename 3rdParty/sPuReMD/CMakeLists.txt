file(GLOB PUREMD_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c")

find_package(OpenMP REQUIRED)

list(REMOVE_ITEM PUREMD_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/driver.c")

add_library(puremd STATIC ${PUREMD_SOURCES})

target_include_directories(puremd PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src        
    ${CMAKE_CURRENT_SOURCE_DIR}/config   
)

target_compile_definitions(puremd PRIVATE HAVE_CONFIG_H)
target_link_libraries(puremd PUBLIC OpenMP::OpenMP_C m)

set_target_properties(puremd PROPERTIES POSITION_INDEPENDENT_CODE ON)