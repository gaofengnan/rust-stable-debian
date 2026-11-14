![GitHub Release](https://img.shields.io/github/v/release/dariogriffo/rust-stable-debian)
![GitHub Release Date](https://img.shields.io/github/release-date/dariogriffo/rust-stable-debian)

<img src="rust-stable-logo.svg" alt="Rust" width="96" align="right">

# rust-stable for Debian and Ubuntu

This repository contains build scripts that produce **unofficial** Debian and
Ubuntu packages (`.deb`) of the latest [Rust](https://www.rust-lang.org/)
stable toolchain, hosted at [deb.griffo.io](https://deb.griffo.io).

The packages repackage the **official Rust release components** from
`static.rust-lang.org`, the very same files `rustup` installs. Nothing is
rebuilt from source. You get one system-wide toolchain, shared by every user on
the machine and updated by apt with each stable release (every six weeks, plus
point releases).

Supported suites: Debian **bookworm, trixie, forky, sid** and Ubuntu **jammy,
noble, questing, resolute**. Architectures: **amd64 and arm64** (a Raspberry
Pi 4/5 on a 64-bit OS takes arm64). The toolchain needs glibc 2.17 or newer,
so every suite gets every package. Upstream also publishes armhf, armel, i386,
ppc64el, s390x, riscv64 and loong64 toolchains; they are not packaged here.

## How the download is verified

Every build checks the release manifest `channel-rust-<version>.toml` against
its detached signature with the Rust release signing key
(`debian/upstream/signing-key.asc`, fingerprint
`108F 6620 5EAE B0AA A8DD 5E1C 85AB 96E6 FA1B E5FE`), then checks every
component tarball against the SHA-256 the manifest records
(`debian/fetch-component`). A mismatch fails the build. The binaries are
installed byte for byte: no stripping, no patching.

## Packages

| Package | Arch | Contents |
| --- | --- | --- |
| `rust-stable` | amd64, arm64 | `rustc`, `cargo`, `rustdoc`, `rustfmt` / `cargo fmt`, `clippy` / `cargo clippy`, `rust-analyzer`, `rust-gdb` / `rust-lldb` and the host's standard library. The toolchain (with its own LLVM) lives in `/usr/lib/rust-stable`, the commands are linked into `/usr/bin`, plus man pages and bash/zsh completions for cargo. |
| `rust-stable-src` | all | Standard library source (rustup's `rust-src`). rust-analyzer needs it for std; recommended by `rust-stable`. |
| `rust-stable-doc` | all | Offline HTML docs (std API, The Book, Rust by Example, the Cargo book, the reference...) under `/usr/share/doc/rust-stable-doc/html`. Large, so only suggested. |
| `rust-stable-std-musl` | amd64, arm64 | Standard library for the host's musl target (`x86_64-unknown-linux-musl` / `aarch64-unknown-linux-musl`), for fully static binaries. Brings its own musl; no `musl-tools` needed. |
| `rust-stable-std-wasm32-unknown-unknown` | all | `wasm32-unknown-unknown` (browser WebAssembly: wasm-bindgen, Trunk, Leptos, Yew). |
| `rust-stable-std-wasm32-wasip1` | all | `wasm32-wasip1` (WASI preview 1: wasmtime, wasmer). |
| `rust-stable-std-wasm32-wasip2` | all | `wasm32-wasip2` (WASI preview 2, components). |

`rust-stable` depends on a C compiler (`gcc` or `clang`) and `libc6-dev`,
which rustc uses as its linker. Installed sizes: about 680 MB for
`rust-stable`, 75 MB for `-src`, 760 MB for `-doc`, 100 to 230 MB per extra
target. Only install the targets you build for.

### Why `rust-stable` and not a newer `rustc`

Debian and Ubuntu package Rust as a family of packages (`rustc`, `cargo`,
`libstd-rust-dev`, `rustfmt`, `rust-clippy`...) that each require exactly the
same version as the others, and the two distributions split it differently.
A newer package that only reused the name `rustc` would leave the
distribution's older standard library next to a newer compiler, and every
build would fail. `rust-stable` keeps the whole toolchain together and
separate from the distribution's packages.

### What it replaces

`rust-stable` Conflicts with and Replaces the packages that own the same
commands: `rustc`, `cargo`, `rustfmt`, `rust-clippy`, `rust-gdb`, `rust-lldb`,
`rust-analyzer` and `rustup` (plus Debian's `*-web` variants and noble's old
`rustc-1.74` / `cargo-1.74`). apt lists what it removes and asks first.
Packages that depend on the distribution's compiler, such as
`python3-setuptools-rust` or `dh-cargo`, are removed with them. Nothing a
system runs needs the compiler, so this only affects Rust development tooling.

It does not touch the system LLVM or clang, and Ubuntu's newer versioned
packages (`rustc-1.97`, `cargo-1.97`...) stay installable side by side: their
commands are named `rustc-1.97` and so on.

To go back to the distribution's toolchain:
`sudo apt remove rust-stable && sudo apt install rustc cargo`.

## Install / Update

### The Debian way (apt)

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/deb.griffo.io.gpg
echo "deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | sudo tee /etc/apt/sources.list.d/deb.griffo.io.list
sudo apt update
sudo apt install rust-stable
```

Add targets as you need them:

```sh
sudo apt install rust-stable-std-musl
cargo build --release --target x86_64-unknown-linux-musl     # aarch64-unknown-linux-musl on arm64
```

### Manual installation

1. Download the `.deb` files for your architecture from the
   [Releases](https://github.com/dariogriffo/rust-stable-debian/releases) page
   (`rust-stable`, `rust-stable-src`, and any extra target).
2. Install them:

```sh
sudo apt install ./rust-stable_*.deb ./rust-stable-src_*.deb
```

## Updating

`sudo apt update && sudo apt upgrade` moves you to each new stable release.
There is no rustup here: `rustup update` and `rustup target add` don't apply.
Add targets with the `rust-stable-std-*` packages. Tools you install with
`cargo install` still go to `~/.cargo/bin` as usual.

If you need nightly, or a target that isn't packaged, use rustup instead of
this package.

## Building locally

Requires Docker (binary packages) and `dpkg-dev`/`devscripts` (source packages):

```sh
./build_debian.sh 1.100.0 1 all   # -> ./out/*.deb        (every suite)
./build_src.sh    1.100.0 1       # -> *.dsc / *.orig.tar.gz / *.debian.tar.xz
```

The arm64 packages are assembled on an amd64 machine: the toolchain is only
unpacked and copied, never executed, so no emulation is needed.

The source package's `.orig.tar.gz` holds the signed release manifest and
upstream's licence files. `debian/rules` downloads the components that
manifest lists and verifies them, so a rebuild from source produces the same
files.

## How releases work

A scheduled workflow (`check-upstream.yml`) reads the current stable version
from `https://static.rust-lang.org/dist/channel-rust-stable.toml`, compares it
with the latest release published here and, when they differ, dispatches
`release.yml`. That validates the upstream licence (MIT or Apache-2.0), builds
all packages for both architectures and publishes a GitHub Release tagged
`<version>+<build>`.

## Disclaimer

- This is an unofficial community packaging project, not affiliated with the
  Rust Project or the Rust Foundation. Rust and the Rust logo are trademarks
  of the Rust Foundation. For Rust itself, see
  [rust-lang.org](https://www.rust-lang.org/) and
  [rust-lang/rust](https://github.com/rust-lang/rust).
- This repo is not for Rust bug reports, only for the Debian packaging.
- Inspired by the packaging approach of
  [neovim-debian](https://github.com/dariogriffo/neovim-debian).
