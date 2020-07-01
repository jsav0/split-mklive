## The Void Linux image/live/rootfs maker and installer - adapted for Split Linux

Split Linux is proudly based on Void Linux. This is how to build it:


Type

    $ make

then build:

    $ ./build-x86-images.sh -a x86_64-musl -b split \
        -r https://kevcrumb.gitlab.io/split-packages/musl


*For the build to finish successfully split packages have to be as recent as the packages they depend on in the official Void repositiores. Otherwise they reference old versions which will not be available anymore.*


See [void-linux/void-mklive](https://github.com/void-linux/void-mklive) for details on the available tools.
