## The Void Linux image/live/rootfs maker and installer - adapted for Split Linux

Split Linux is proudly based on Void Linux. This is how to build it:


Type

    $ make

then build Split Linux:

    $ ./build-x86-images.sh -a x86_64-musl -b split -r https://gitlab.com/kevcrumb/split-packages/-/raw/master/hostdir/binpkgs


See [void-linux/void-mklive](https://github.com/void-linux/void-mklive) for details on the available tools.
