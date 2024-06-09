### A Rust crate browser for GNOME.

It is very minimal in design and implementation and written in Zig.

Building does not install anything on the system. Instead the binary can install the system files by itself:
```sh
zig build
zig-out/bin/crates --install # or just -i
```

Building depends on the libadwaita-1 development package and the Zig compiler.
It may not build with the latest compiler as it is very unstable but it should always be up to date with my fork of Zig.

Cross compilation is possible but requires shared libraries to be present for the target.

![image](https://github.com/TeamPuzel/Crates/assets/94306330/4a2bb43e-1dd2-4fbe-be94-41dff84d3983)

![image](https://github.com/TeamPuzel/Crates/assets/94306330/db274838-187f-457a-86b2-ae8d436fef15)
