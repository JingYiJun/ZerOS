const std = @import("std");
const Target = std.Target;
const Model = Target.Cpu.Model;
const Feature = Target.Cpu.Feature;
const CrossTarget = std.zig.CrossTarget;
const fs = std.fs;

pub fn build(b: *std.Build) !void {
    const target = CrossTarget{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &Target.aarch64.cpu.cortex_a53 },
        .abi = .eabi,
    };

    const optimize = b.standardOptimizeOption(.{});

    const kernel_name = "kernel8";

    // build kernel.elf
    const kernel_elf_name = kernel_name ++ ".elf";
    const kernel_elf_path = b.getInstallPath(.bin, kernel_elf_name);
    const kernel = b.addExecutable(.{
        .name = kernel_elf_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .linkage = .static,
        .link_libc = false,
        .target = target,
        .optimize = optimize,
    });
    kernel.force_pic = false;
    kernel.pie = false;
    kernel.disable_stack_probing = true;
    kernel.stack_protector = false;
    kernel.setLinkerScript(.{ .path = "src/linker.ld" });
    kernel.addAssemblyFile(.{ .path = "src/start.S" });
    kernel.addCSourceFile(.{
        .file = .{ .path = "src/aarch64/kernel_pt.c" },
        .flags = &.{ "-Wall", "-Wextra", "-Wconversion", "-Wsign-conversion" },
    });
    kernel.addIncludePath(.{ .path = "src" });
    b.installArtifact(kernel);

    // get kernel.asm
    const kernel_asm_name = kernel_name ++ ".asm";
    const kernel_asm_error = kernel_name ++ ".asm.log";
    const kernel_asm_path = b.getInstallPath(.bin, kernel_asm_name);
    const kernel_asm_error_path = b.getInstallPath(.bin, kernel_asm_error);
    const kernel_asm = b.addSystemCommand(&.{
        "llvm-objdump-16",
        "--arch-name=aarch64",
        "--source",
        "--disassemble-all",
        kernel_elf_path,
    });
    kernel_asm.step.dependOn(b.getInstallStep());

    // get kernel.hdr
    const kernel_hdr_name = kernel_name ++ ".hdr";
    const kernel_hdr_path = b.getInstallPath(.bin, kernel_hdr_name);
    const kernel_hdr = b.addSystemCommand(&.{
        "llvm-objdump-16",
        "--all-headers",
        kernel_elf_path,
    });

    // relocate stdout and stderr to files
    const kernel_asm_output = b.addWriteFiles();
    _ = kernel_asm_output.addCopyFile(kernel_asm.captureStdOut(), kernel_asm_path);
    _ = kernel_asm_output.addCopyFile(kernel_asm.captureStdErr(), kernel_asm_error_path);
    _ = kernel_asm_output.addCopyFile(kernel_hdr.captureStdOut(), kernel_hdr_path);
    kernel_asm_output.step.dependOn(&kernel_asm.step);
    kernel_asm_output.step.dependOn(&kernel_hdr.step);

    // build kernel.img
    const kernel_img_name = kernel_name ++ ".img";
    const kernel_img_path = b.getInstallPath(.bin, kernel_img_name);
    const kernel_img = b.addSystemCommand(&.{
        "llvm-objcopy-16",
        "-I",
        "elf64-aarch64",
        "-O",
        "binary",
        kernel_elf_path,
        kernel_img_path,
    });
    kernel_img.step.dependOn(b.getInstallStep());

    // start qemu if use `zig build qemu`
    const qemu_step = b.step("qemu", "Run ZerOS in qemu");
    const qemu_command = b.addSystemCommand(&.{
        "qemu-system-aarch64",
        "--machine",
        "raspi3b",
        "-nographic",
        "-serial",
        "null",
        "-serial",
        "mon:stdio",
        "-kernel",
        kernel_img_path,
    });

    qemu_command.step.dependOn(&kernel_img.step);
    qemu_command.step.dependOn(&kernel_asm_output.step);
    qemu_step.dependOn(&qemu_command.step);

    // start qemu debug
    const qemu_debug_step = b.step("qemu-debug", "Run ZerOS in qemu with gdb");
    const qemu_debug_command = b.addSystemCommand(&.{
        "qemu-system-aarch64",
        "--machine",
        "raspi3b",
        "-nographic",
        "-serial",
        "null",
        "-serial",
        "mon:stdio",
        "-kernel",
        kernel_img_path,
        "-gdb",
        "tcp::1234",
        "-S",
    });
    qemu_debug_command.step.dependOn(&kernel_img.step);
    qemu_debug_step.dependOn(&qemu_debug_command.step);

    // uninstall step
    // currently must use this to push installed files
    // - https://github.com/ziglang/zig/issues/14943
    b.pushInstalledFile(.bin, kernel_elf_name);
    b.pushInstalledFile(.bin, kernel_img_name);
    b.pushInstalledFile(.bin, kernel_asm_name);
    b.pushInstalledFile(.bin, kernel_asm_error);
    b.pushInstalledFile(.bin, kernel_hdr_name);

    // clean step
    // remove zig-cache and `prefix path`
    const clean_step = b.step("clean", "Clean prefix path and zig-cache");
    const clean_command = b.addSystemCommand(&.{
        "rm",
        "-rf",
        "zig-cache",
        b.getInstallPath(.prefix, ""),
    });
    clean_step.dependOn(&clean_command.step);
}
