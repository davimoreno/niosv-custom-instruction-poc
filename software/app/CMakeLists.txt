cmake_minimum_required(VERSION 3.14)

add_subdirectory(../bsp bsp)

include(../bsp/toolchain.cmake)

project(hello)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

add_executable(hello.elf)

target_sources(hello.elf
    PRIVATE
        hello.c
)

target_include_directories(hello.elf
    PRIVATE
    PUBLIC
)

target_link_libraries(hello.elf
    PRIVATE
        -T "${BspLinkerScript}" -nostdlib
        "${ExtraArchiveLibraries}"
        -Wl,--start-group "${BspLibraryName}" -lc -lstdc++ -lgcc -lm -Wl,--end-group
)

# Create objdump from ELF.
set(objdump hello.elf.objdump)
add_custom_command(
    OUTPUT "${objdump}"
    DEPENDS hello.elf
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}" hello.elf >
            "${objdump}"
    COMMENT "Creating ${objdump}."
    VERBATIM
)
add_custom_target(create-objdump ALL DEPENDS "${objdump}")

# Report space free for stack + heap. Note that the file below is never created
# so the report is always output on build.
set(stack_report_file hello.elf.stack_report)
add_custom_command(
    OUTPUT "${stack_report_file}"
    DEPENDS hello.elf
    COMMAND niosv-stack-report -p "${ToolchainPrefix}" hello.elf
    COMMENT "Reporting memory available for stack + heap in hello.elf."
    VERBATIM
)
add_custom_target(niosv-stack-report ALL DEPENDS "${stack_report_file}")

# Generate HEX file(s) from hello.elf using elf2hex tool.
# Note : If ECC Full is enabled, width of 39 is set for NiosV TCM. Otherwise, 32.
add_custom_command(
    OUTPUT "onchip_ram.hex"
    DEPENDS hello.elf
    COMMAND elf2hex hello.elf -o onchip_ram.hex -b 0x00000000 -w 32 -e 0x0001FFFF -r 4
    COMMENT "Creating onchip_ram.hex."
    VERBATIM
)
add_custom_target(create-hex ALL DEPENDS "onchip_ram.hex")
