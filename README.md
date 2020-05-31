## The Void Linux image/live/rootfs maker and installer - adapted for Split Linux

Split Linux is proudly based on Void Linux. This is how to build it:


Type

    $ make

then build Split Linux:

    $ ./build-x86-images.sh -a x86_64-musl -b split -r https://gitlab.com/kevcrumb/split-packages/hostdir/binpkgs-/raw/master/


When asked to accept signatures, verify the fingerprint and press enter:

    `https://gitlab.com/kevcrumb/split-packages/-/raw/master/hostdir/binpkgs' repository has been RSA signed by "Kevin Crumb <kevcrumb@splitlinux.org>"
    Fingerprint: 2e:cd:12:9f:a9:b8:fe:b3:36:ae:d2:cf:56:47:8d:ce
    Do you want to import this public key? [Y/n]


See voidlinux/void-mklive for details on the available tools.
