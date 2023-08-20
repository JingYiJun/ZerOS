# ZerOS

用 [Zig](https://ziglang.org/) 写的简易操作系统，用于复旦大学 2023 年秋季学期《操作系统》课程的配套实验。

名字随便起的，寓意 Zero OS 即自己的第一个操作系统。~~不如放一只可爱猫猫~~

为什么用 Zig？因为比 C 更现代化，有包管理和一部分语法糖；比 Rust 更能操作内存且心智负担稍小。而且 Zig 有强大的编译期计算和静态反射能力，一部分标准库也可以在裸金属上使用，并且可以和 C 代码无缝集成。

> 但是 Zig 语言有很多小毛病，稳定性不如 Rust。o(╥﹏╥)o

## 特点

- 目前只能跑在树莓派 3B 上，在 qemu 上能通过测试。
- 尽量使用 Zig 语言

## 构建指南

### 前置要求

#### 安装 Zig

Zig 目前正在快速迭代，每个小版本的 API 都会有很大变动。官方推荐用最新的 master 分支。

安装过程详见：https://ziglang.org/learn/getting-started/，源码仓库：https://github.com/ziglang/zig

如果从源码构建，需要安装 `clang-16 libclang-16-dev llvm-16 libllvm-16-dev lld-16 liblld-16-dev zstd libzstd-dev` ，必须是 16 版本。CMake 构建必须要指定 `CLANG_INCLUDE_DIRS` 和 `LLD_INCLUDE_DIRS`。

这是我的构建命令：

```shell
mkdir build && cd build
cmake .. -DCLANG_INCLUDE_DIRS=/usr/lib/clang/16 -DLLD_INCLUDE_DIRS=/usr/lib/llvm-16 -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release
make -j && make install
```

#### 建议安装 zls

zls 是 Zig 的语言服务器，建议安装。

[zls](https://github.com/zigtools/zls)。要求使用本地 Zig 构建。

zls 项目根目录下，我的构建命令是：

```shell
zig build -Doptimize=ReleaseFast -Ddata_version=master --verbose -p /usr/local
```

#### VS Code 配置 Zig 开发环境

我的开发环境是 VS Code + wsl2，使用 Zig 官方的 VS Code 插件可以获得语法高亮、补全、跳转、格式化等功能。

VS Code 支持用 C/C++ 的远程调试功能调试 Zig 代码。详见 [知乎：VS Code与GDB Server远程调试](https://zhuanlan.zhihu.com/p/295099630) 和 [知乎：在 Windows 版 VS Code 中调试 Zig 代码](https://zhuanlan.zhihu.com/p/463740524)

为什么不用 CLion？目前 JetBrains 系 IDE 的远程功能比较烂，运行成本高。

### 构建本项目

Zig 项目会尽可能使用 `build.zig` 构建脚本构建程序，尽量不使用 `make`。同时会使用到 `llvm-objdump-16` 和 `llvm-objcopy-16`。不使用 `aarch64-linux-gnu-*` 的软件。

使用 ```zig build --help``` 获得所有帮助。

#### 构建 ELF

```shell
zig build
```

这会将项目构建为 elf 格式，默认安装到 `zig-out/bin` 目录下。只会构建到 `kernel8.elf`。

#### 直接启动 qemu 

```shell
zig build qemu
```

这一步会构建 `kernel8.elf`, `kernel8.asm`, `kernel8.hdr`, `kernel8.img` 并且启动 qemu。

#### qemu + gdb

```shell
zig build qemu-debug
```

在启动 qemu 的同时启动 gdb-server，监听 tcp::1234。

### 项目清理

#### 清理输出文件

```shell
zig build uninstall
```

这会清除 `zig build` 的输出文件。

#### 清理构建缓存

```shell
zig build clean
```

这会直接删除 `zig-out` 和 `zig-cache` 文件夹。

## 目标

- [ ] 完成 OS 实验要求。
- [ ] 内核 panic 时打印调用栈信息，基于 https://andrewkelley.me/post/zig-stack-traces-kernel-panic-bare-bones-os.html。
- [ ] 跑在香橙派和其他的 aarch64 开发板上。
- [ ] 移植一些系统级应用程序。

## 已知问题

- 构建得到的 `kernel8.elf` debug 信息引用了不存在的行，错误信息会输出到 `kernel8.asm.log`。
- 目前的 Zig 不支持[链接时全局变量初始化](https://github.com/ziglang/zig/issues/9512)，而页表 `kernel_pt.c` 依赖于这一点，所以不方便移植到 Zig。但是实际上只有 `start.S` 依赖于这个文件，所以我直接拿过来，利用 Zig 无缝衔接 C 的特性把 `kernel_pt.c` 缝进了项目里面。

## 参考项目

- [Fudan 2022Fall OS](https://github.com/FDUCSLG/OS-2022Fall-Fudan)
- [Fudan 2021Fall OS](https://github.com/FDUCSLG/OS-2021Fall-dev)
- [w568w's Rarmo](https://github.com/w568w/Rarmo)
- [rCore-Tutorial-Book-v3](https://rcore-os.github.io/rCore-Tutorial-Book-v3/)
- [Pluto: An x86 kernel written in Zig](https://github.com/ZystemOS/pluto)
- [ClashOS: multiplayer arcade game for bare metal Raspberry Pi 3 B+](https://github.com/andrewrk/clashos)
- [raspi3-tutorial](https://github.com/bztsrc/raspi3-tutorial)

## 开源许可证

本项目以 MIT 许可证开源。