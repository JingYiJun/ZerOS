const std = @import("std");
const Target = std.Target;
const Model = Target.Cpu.Model;
const Feature = Target.Cpu.Feature;
const CrossTarget = std.zig.CrossTarget;
const fs = std.fs;
const allocPrint = std.fmt.allocPrint;
const comptimePrint = std.fmt.comptimePrint;
const StringList = std.ArrayList([]const u8);

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
    kernel_hdr.step.dependOn(b.getInstallStep());

    // delete output files before output
    const kernel_asm_output_clean = b.addSystemCommand(&.{
        "rm",
        "-rf",
        kernel_asm_path,
        kernel_asm_error_path,
        kernel_hdr_path,
    });

    // relocate stdout and stderr to files
    const kernel_asm_output = b.addWriteFiles();
    kernel_asm_output.step.dependOn(&kernel_asm_output_clean.step);
    kernel_asm_output.step.dependOn(&kernel_asm.step);
    kernel_asm_output.step.dependOn(&kernel_hdr.step);
    kernel_asm_output.addCopyFileToSource(kernel_asm.captureStdOut(), kernel_asm_path);
    kernel_asm_output.addCopyFileToSource(kernel_asm.captureStdErr(), kernel_asm_error_path);
    kernel_asm_output.addCopyFileToSource(kernel_hdr.captureStdOut(), kernel_hdr_path);

    const kernel_asm_step = b.step("kernel-asm", "output-kernel-asm");
    kernel_asm_step.dependOn(&kernel_asm_output.step);

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

    // build fs.img
    // first: generate fs.img and make fat32 filesystem
    var fs_files = StringList.init(b.allocator);
    try fs_files.appendSlice(&.{
        kernel_img_path,
        "armstub8-rpi4.bin",
        "bootcode.bin",
        "config.txt",
        "fixup_cd.dat",
        "fixup.dat",
        "fixup4.dat",
        "fixup4cd.dat",
        "LICENCE.broadcom",
        "start_cd.elf",
        "start.elf",
        "start4.elf",
        "start4cd.elf",
    });
    const boot_img_name = "boot.img";
    const boot_img_path = b.getInstallPath(.bin, boot_img_name);
    const n_boot_sectors = 128 * 1024;
    const sector_size = 512;

    var generate_boot_img = b.addSystemCommand(&.{
        "dd",
        "if=/dev/zero",
        try allocPrint(b.allocator, "of={s}", .{boot_img_path}),
        try allocPrint(b.allocator, "seek={d}", .{n_boot_sectors - 1}),
        try allocPrint(b.allocator, "bs={d}", .{sector_size}),
        "count=1",
    });

    var generate_boot_img_fs = b.addSystemCommand(&.{
        "mkfs.vfat",
        "-F",
        "32",
        "-s",
        "1",
        boot_img_path,
    });
    generate_boot_img_fs.step.dependOn(&generate_boot_img.step);

    // copy files into boot partition
    const copy_files_into_boot_partition_step = b.step("copy_files", "copy_files");
    copy_files_into_boot_partition_step.dependOn(&generate_boot_img_fs.step);
    for (fs_files.items) |file| {
        const copy_file = b.addSystemCommand(&.{
            "mcopy",
            "-i",
            boot_img_path,
            file,
            try allocPrint(b.allocator, "::{s}", .{fs.path.basename(file)}),
        });
        copy_file.cwd = "boot";
        copy_file.step.dependOn(&generate_boot_img_fs.step);
        if (std.mem.eql(u8, fs.path.basename(file), kernel_img_name)) {
            copy_file.step.dependOn(&kernel_img.step);
        }
        copy_files_into_boot_partition_step.dependOn(&copy_file.step);
    }

    // start qemu if use `zig build qemu`
    const qemu_step = b.step("qemu", "Run ZerOS in qemu");
    var qemu_args = std.ArrayList([]const u8).init(b.allocator);
    defer qemu_args.deinit();
    try qemu_args.appendSlice(&.{
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
    var current_qemu_args = try qemu_args.clone();
    const qemu_command = b.addSystemCommand(try current_qemu_args.toOwnedSlice());

    qemu_command.step.dependOn(&kernel_img.step);
    qemu_command.step.dependOn(&kernel_asm_output_clean.step);
    qemu_command.step.dependOn(&kernel_asm_output.step);
    qemu_command.step.dependOn(copy_files_into_boot_partition_step);
    qemu_step.dependOn(&qemu_command.step);

    // start qemu debug
    const qemu_debug_step = b.step("qemu-debug", "Run ZerOS in qemu with gdb");
    current_qemu_args = try qemu_args.clone();
    try current_qemu_args.appendSlice(&.{
        "-gdb",
        "tcp::1234",
        "-S",
    });
    const qemu_debug_command = b.addSystemCommand(try current_qemu_args.toOwnedSlice());
    qemu_debug_command.step.dependOn(&kernel_img.step);
    qemu_debug_command.step.dependOn(&kernel_asm_output_clean.step);
    qemu_debug_command.step.dependOn(&kernel_asm_output.step);
    qemu_debug_command.step.dependOn(copy_files_into_boot_partition_step);
    qemu_debug_step.dependOn(&qemu_debug_command.step);

    // uninstall step
    // currently must use this to push installed files
    // - https://github.com/ziglang/zig/issues/14943
    b.pushInstalledFile(.bin, kernel_elf_name);
    b.pushInstalledFile(.bin, kernel_img_name);
    b.pushInstalledFile(.bin, kernel_asm_name);
    b.pushInstalledFile(.bin, kernel_asm_error);
    b.pushInstalledFile(.bin, kernel_hdr_name);
    b.pushInstalledFile(.bin, boot_img_name);

    // clean step
    // remove zig-cache and `prefix path`
    const clean_step = b.step("clean", "Clean prefix path and zig-cache");
    const clean_command = b.addSystemCommand(&.{
        "rm",
        "-rf",
        "zig-cache",
        b.getInstallPath(.bin, "*"),
    });
    clean_step.dependOn(&clean_command.step);
}
