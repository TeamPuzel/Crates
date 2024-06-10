### A Rust crate browser for GNOME.

It is very minimal in design and implementation and written in Zig.

Building does not install anything on the system. Instead the binary can install the system files by itself:
```sh
zig build
zig-out/bin/crates --install # or just -i
```

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

![image](https://github.com/TeamPuzel/Crates/assets/94306330/4a2bb43e-1dd2-4fbe-be94-41dff84d3983)

![image](https://github.com/TeamPuzel/Crates/assets/94306330/db274838-187f-457a-86b2-ae8d436fef15)
