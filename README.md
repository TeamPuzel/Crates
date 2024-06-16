### A Rust crate browser for GNOME and Cocoa.

It is very minimal in design and implementation and written in Zig.

On macOS this application depends on my [Objective-Zig](https://github.com/TeamPuzel/Objective-Zig) library.

Building does not install anything on the system. Instead the binary can install the system files by itself:
```sh
zig build
zig-out/bin/crates --install # or just -i
```

Options for running are:
```sh
zig build run-cocoa # Cocoa frontend, macOS only
zig build run-gnome # GNOME frontend, linux and macOS (but it's so bad on macOS it isn't usable)
zig build run       # Default frontend for the target platform
```

Installing is somewhat unfinished right now.

Building depends only on the libadwaita-1 shared library and headers, and of course the Zig compiler.
It may not build with the latest compiler as it is quite unstable but it should always be up to date with my fork of Zig.

Cross compilation is possible but requires shared libraries to be present for the target.
In fact it should be able to cross compile from a completely different (unix-like) operating system.

Use this command (with the libraries present) to cross compile and create tar.xz bundles for flatpak:
```sh
zig build bundle
```

There are useful configuration options you can specify, use Zig to query what they are.
The most important one is `-Dstable` which will configure the window to use the default
appearance instead of the development window and remove all references to it being a dev build.
It should only be used for stable releases of the application.

![Screenshot from 2024-06-10 17-07-08](https://github.com/TeamPuzel/Crates/assets/94306330/35086337-6524-4708-b6db-78506baf197e)

![Screenshot from 2024-06-10 17-07-39](https://github.com/TeamPuzel/Crates/assets/94306330/5d388d95-9e47-45a2-bcc7-51a9fe062e9e)
