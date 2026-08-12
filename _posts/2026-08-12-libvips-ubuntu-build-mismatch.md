---
layout: post
title: "When Ubuntu Builds Fail on libvips but macOS Does Not"
description: "Why a Rails test suite can fail because Ubuntu ships an older native libvips, how ruby-vips fits into the picture, and how to upgrade libvips safely without confusing the system package with the Ruby gem."
date: 2026-08-12 22:00:00 +0100
author: "Joey Wang"
tags: [ruby, rails, libvips, ubuntu, macos, testing, native-dependencies]
categories: [Engineering, DevOps]
---

# When Ubuntu Builds Fail on libvips but macOS Does Not

A Rails test suite can work perfectly on a MacBook and fail before the first example runs on an Ubuntu build machine. That sounds like an application bug, but sometimes the application has not even started yet. The failure is in a native dependency loaded during Rails boot.

I recently hit this with a Rails application using Active Storage and `ruby-vips`. The error was essentially:

```text
libvips's unfuzzed operations are not safe to use with untrusted content,
and Active Storage cannot disable them.

Disabling them requires libvips 8.13 or later and ruby-vips 2.2.1 or later.
```

The Ruby dependency was already new enough. The native library on the Ubuntu host was not.

The important lesson is this:

> `ruby-vips` is a Ruby wrapper, not the image-processing engine itself. The wrapper still loads the native `libvips` shared library installed by the operating system or by a separate native build.

## The short version

On the Ubuntu ARM build host used for this investigation, the versions were:

```text
Ubuntu:     22.04.5 LTS, arm64
libvips:    8.12.1
ruby-vips:  2.3.0
```

`ruby-vips` satisfied the Ruby-side requirement, but Ubuntu's standard Jammy repository provided libvips 8.12.1. Active Storage requires libvips 8.13 or later for the security behavior it needs, so Rails aborted during initialization.

After installing libvips 8.18.3 under a separate system prefix, the same check reported:

```text
ruby-vips 2.3.0
libvips 8.18.3
```

The focused spec then passed:

```text
3 examples, 0 failures
```

## Why this happens on Ubuntu but not on a MacBook

This is not because Ubuntu cannot run libvips, and it is not because macOS is inherently more compatible. The difference is usually the package source and release cadence.

### Ubuntu LTS favors stability

Ubuntu LTS releases intentionally keep major system packages stable for the lifetime of the release. On Ubuntu 22.04, the standard ARM repository can therefore provide libvips 8.12.1 even though newer libvips releases exist upstream.

That is a useful server property: security updates and compatibility fixes are preferred over continuously changing feature versions. It also means that a build requiring a newer native library may outgrow the distribution package.

Check the actual package before assuming anything:

```bash
cat /etc/os-release
uname -m
apt-cache policy libvips42 libvips-dev
vips --version
```

On Debian-family systems, the runtime package is commonly named `libvips42` and the headers/build metadata are in `libvips-dev`.

### Homebrew usually tracks newer software

On macOS, libvips is commonly installed through Homebrew:

```bash
brew install vips
vips --version
```

Homebrew is a rolling package ecosystem rather than an Ubuntu-LTS snapshot. A MacBook that was set up or updated recently may therefore have a libvips version new enough for the Rails dependency, while an Ubuntu build machine still has the older LTS package.

The right comparison is not “Mac versus Linux.” Compare these instead:

```text
Ruby version
ruby-vips gem version
native libvips version
architecture
package source
library search path
```

A MacBook may also be using a Homebrew-provided ARM64 or x86_64 library, while the Ubuntu builder is using an ARM64 distribution package. Both can be valid installations with different versions.

## Three layers that are easy to confuse

There are three separate pieces in this failure:

```text
Rails / Active Storage
        │
        ▼
ruby-vips Ruby gem
        │  FFI / native loading
        ▼
libvips shared library
        │
        ▼
Ubuntu package or source installation
```

### 1. Rails and Active Storage

Active Storage uses image-processing backends and checks whether the native library has the security controls it needs. This check can happen while the Rails application boots, which is why the test runner can fail before reporting any examples.

### 2. The `ruby-vips` gem

The gem provides Ruby classes and bindings. Check it through Bundler, not only through the system Ruby:

```bash
bundle info ruby-vips
bundle exec ruby -e 'require "vips"; puts Vips::VERSION'
```

The project may use a different Ruby from `/usr/bin/ruby`, especially when it uses mise, rbenv, or asdf.

### 3. The native libvips library

The wrapper loads the shared library found through the dynamic linker. Check the version that the Ruby process actually sees:

```bash
bundle exec ruby -e 'require "vips"; puts Vips::LIBRARY_VERSION'
```

This is more useful than checking only `vips --version`. The command-line binary and Ruby process can resolve different libraries if `/usr/local`, Homebrew, or a custom `LD_LIBRARY_PATH` is involved.

## The safest first fix: use the distribution package if it is new enough

Before compiling anything, check whether the configured Ubuntu repositories already provide a sufficient version:

```bash
sudo apt update
apt-cache policy libvips42 libvips-dev
```

If the candidate is 8.13 or newer, install both the runtime and development packages:

```bash
sudo apt install libvips42 libvips-dev
```

Then verify both the CLI and the Ruby binding:

```bash
vips --version
bundle exec ruby -e 'require "vips"; puts Vips::LIBRARY_VERSION'
```

Installing only `libvips-dev` is not enough. The build headers may be present while the runtime still loads the old shared library. Conversely, installing only the runtime package may leave native extensions or build checks without the headers and `pkg-config` metadata they need.

## Building a newer libvips from source

When Ubuntu's package is too old, building a newer upstream release is a practical option for a dedicated build host. The official libvips installation guide recommends Meson and Ninja for source builds.

The following example installs libvips 8.18.3 into `/usr/local`. Choose a release that is appropriate for the project and verify its checksum or signature according to your environment's policy.

### Install build prerequisites

The exact optional dependencies determine which image formats libvips supports. Start with the core build tools:

```bash
sudo apt update
sudo apt install \
  build-essential \
  meson \
  ninja-build \
  pkg-config \
  libglib2.0-dev \
  libexpat1-dev \
  libjpeg-turbo8-dev \
  libtiff5-dev \
  libpng-dev \
  libwebp-dev \
  libarchive-dev
```

You can add development packages for formats your application needs. Inspect the Meson summary carefully; a successful compilation does not necessarily mean every optional image loader was enabled.

### Download and configure the release

```bash
mkdir -p "$HOME/tmp/libvips-build"
cd "$HOME/tmp/libvips-build"

curl -fL --retry 3 \
  -o libvips-8.18.3.tar.xz \
  https://github.com/libvips/libvips/releases/download/v8.18.3/libvips-8.18.3.tar.xz

tar -xf libvips-8.18.3.tar.xz
cd libvips-8.18.3

meson setup build \
  --prefix=/usr/local \
  --libdir=lib \
  --buildtype=release
```

The `--libdir=lib` option is useful on Debian-family systems because it avoids putting the library under a multiarch path such as `lib/aarch64-linux-gnu`. Either layout can work; consistency matters more than the exact choice.

Read the Meson summary before continuing:

```bash
meson configure build
```

### Compile, test, and install

```bash
meson compile -C build
meson test -C build
sudo meson install -C build
sudo ldconfig
```

`ldconfig` refreshes the dynamic linker cache so processes can find the newly installed shared library. Without it, the `vips` executable or Ruby process may continue loading the distribution copy.

Verify the result:

```bash
/usr/local/bin/vips --version
vips --version

bundle exec ruby -e \
  'require "vips"; puts "ruby-vips #{Vips::VERSION}"; puts "libvips #{Vips::LIBRARY_VERSION}"'
```

The important output is the `Vips::LIBRARY_VERSION` value observed by the same Bundler environment that runs the Rails tests.

## When `LD_LIBRARY_PATH` is needed

A custom installation may be in a library directory that is not yet in the linker configuration. For a temporary test, set:

```bash
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/aarch64-linux-gnu
```

Then rerun the Ruby check and the spec:

```bash
DATABASE_HOST=/path/to/local/postgres/socket \
CI=true \
LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/$(uname -m)-linux-gnu \
bundle exec rspec spec/tasks/remove_copy_suffixes_spec.rb
```

For a permanent machine configuration, prefer a linker configuration file instead of putting `LD_LIBRARY_PATH` into every CI command:

```bash
printf '%s\n' /usr/local/lib > /tmp/usr-local-lib.conf
sudo mv /tmp/usr-local-lib.conf /etc/ld.so.conf.d/usr-local-lib.conf
sudo ldconfig
ldconfig -p | grep libvips
```

Use the actual directory where `libvips.so` was installed. Do not add a path blindly; confirm it first:

```bash
find /usr/local -name 'libvips.so*' -print
```

## Diagnose which library is being loaded

If the version still looks wrong, inspect the executable and the Ruby process rather than guessing.

For the CLI:

```bash
command -v vips
ldd "$(command -v vips)" | grep -E 'vips|glib|expat'
```

For Ruby, first locate the FFI-loaded library and then inspect the process while it is running. A simpler first check is usually enough:

```bash
bundle exec ruby -e 'require "vips"; abort "old libvips" unless Vips::LIBRARY_VERSION >= "8.13"; puts Vips::LIBRARY_VERSION'
```

Also check for multiple installations:

```bash
find /usr /usr/local -name 'libvips.so*' -o -name 'vips' 2>/dev/null
```

Common causes of a mismatch include:

- `/usr/bin/vips` is from apt but Ruby loads `/usr/local/lib`.
- The new library was installed but `ldconfig` was not run.
- `LD_LIBRARY_PATH` points to an older build.
- The shell uses one Ruby while Bundler uses another.
- The build host is ARM64 but a copied binary or package targets another architecture.

## Re-run Rails at the same layer as CI

Once the native version is correct, run the smallest failing spec first:

```bash
DATABASE_HOST=/path/to/local/postgres/socket \
CI=true \
LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/$(uname -m)-linux-gnu \
bundle exec rspec spec/tasks/remove_copy_suffixes_spec.rb
```

Then run the repository's normal test command. Keep the environment explicit so a local interactive shell does not hide a missing CI dependency.

A successful native check does not prove the whole application is correct. It only proves that the process can load a compatible libvips. The Rails test suite still needs its database, browser, JavaScript, and application-level dependencies.

## Should libvips be upgraded on every Ubuntu machine?

No. There are several reasonable strategies:

### Pin a newer OS package

Best when the organization has a trusted repository or image-building process that supplies the required version. It keeps upgrades integrated with package management, but introduces repository and support decisions.

### Build libvips into the CI image

Best when CI is containerized or image-based. The native version becomes part of a reproducible builder image instead of an undocumented manual server change.

### Build into a private prefix

Best for a single dedicated host where you want to avoid replacing Ubuntu-managed files. `/usr/local` is separate from `/usr`, and the install can be removed or replaced deliberately. Document the linker path and the exact source release.

### Upgrade Ubuntu

Best when the build host is already due for an OS refresh. A newer Ubuntu release may provide a newer libvips package, but an OS upgrade is a much larger change than a single library upgrade.

The least desirable option is to overwrite files owned by apt under `/usr/lib` manually. That makes future package upgrades and incident recovery harder.

## A repeatable verification checklist

When the MacBook passes and Ubuntu fails, record this information on both machines:

```bash
uname -m
ruby --version
bundle --version
bundle info ruby-vips
bundle exec ruby -e 'require "vips"; puts Vips::VERSION; puts Vips::LIBRARY_VERSION'
vips --version
```

Then compare:

1. Ruby and Bundler versions.
2. `ruby-vips` gem version.
3. Native `libvips` version loaded by Ruby.
4. CPU architecture.
5. Package manager and package source.
6. Dynamic-library search paths.
7. The exact test command and environment variables.

This turns “it only fails on Ubuntu” into a concrete dependency difference.

## Final thoughts

Native dependencies live below the Ruby dependency file. Bundler can resolve `ruby-vips` successfully while the operating system still provides an incompatible libvips. macOS and Ubuntu can therefore run the same Rails code with different native behavior because their package ecosystems move at different speeds.

The durable fix is not to disable the safety check. It is to make the build environment explicit: use a compatible native libvips, verify the version from inside the Bundler process, install it through a repeatable package or image workflow, and document the linker configuration.

Once those layers are checked separately, the failure is straightforward: the application was not broken; the Ubuntu builder was loading an older native library than the Rails dependency allowed.

## References

- [libvips installation guide](https://www.libvips.org/install.html)
- [libvips releases](https://github.com/libvips/libvips/releases)
- [libvips 8.18.3 release notes](https://github.com/libvips/libvips/releases/tag/v8.18.3)
- [ruby-vips](https://github.com/libvips/ruby-vips)
