#!/bin/sh

set -o nounset
set -o errexit

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/utilities.sh"

# Install git.
# If it's too old to be used in GitHub Actions we'll build it.
#
# Arguments:
#   $1: the version to be built if the one provided by apt is too old
installGit() {
    if isAptPackageAtLeastVersion git 2.18.0; then
        echo "Installing system-provided git since it's recent enough"
        installAptPackages git
        return
    fi
    echo 'Compiling git since the system-provided one is too old'
    installAptPackages '^libcurl[0-9]*-gnutls$ ^libexpat[0-9]*$ gettext ^zlib([0-9]+[a-z]*)$' 'libssl-dev ^libcurl[0-9]*-gnutls-dev$ ^libexpat[0-9]*-dev$ ^zlib([0-9]+[a-z]*)?-dev$'
    printf 'Downloading git v%s... ' "$1"
    installGit_dir="$(mktemp -d)"
    curl -ksSLf -o - https://codeload.github.com/git/git/tar.gz/refs/tags/v$1 | tar xzm -C "$installGit_dir"
    printf 'done.\n'
    cd "$installGit_dir/git-$1"
    make -j$(nproc) prefix=/usr/local install
    cd - >/dev/null
    rm -rf "$installGit_dir"
    markPackagesAsInstalledByName git
    markPackagesAsInstalledByRegex '^libgit'
    git version --build-options
}

# Try to install libaom.
#
# Arguments:
#   $1: the version to be installed
installLibaom() {
    if ! isCMakeAtLeastVersion '3.6'; then
        echo 'libaom not installed because cmake is too old' >&2
        return
    fi
    installAptPackages '' 'cmake ninja-build nasm'
    printf 'Downloading libaom v%s... ' "$1"
    installLibaom_dir="$(mktemp -d)"
    curl -ksSLf -o - https://aomedia.googlesource.com/aom/+archive/v$1.tar.gz | tar xzm -C "$installLibaom_dir"
    printf 'done.\n'
	mkdir "$installLibaom_dir/my.build"
	cd "$installLibaom_dir/my.build"
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0 -DCMAKE_INSTALL_LIBDIR:PATH=lib ..
	ninja -j $(nproc) install
	cd - >/dev/null
    rm -rf "$installLibaom_dir"
	ldconfig
    markPackagesAsInstalledByRegex '^(lib)?aom([0-9]|-dev)'
    pkg-config --list-all | grep -E '^(lib)?aom\s'
}

# Try to install libdav1d.
#
# Arguments:
#   $1: the version to be installed
installLibdav1d() {
    if ! isMesonAtLeastVersion '0.44'; then
        echo 'libdav1d not installed because meson is too old' >&2
        return
    fi
    installAptPackages '' 'meson ninja-build nasm'
    printf 'Downloading libdav1d v%s... ' "$1"
    installLibdav1d_dir="$(mktemp -d)"
    curl -ksSLf -o - https://code.videolan.org/videolan/dav1d/-/archive/$1/dav1d-$1.tar.gz | tar xzm -C "$installLibdav1d_dir"
    printf 'done.\n'
    mkdir "$installLibdav1d_dir/dav1d-$1/build"
	cd "$installLibdav1d_dir/dav1d-$1/build"
	meson --buildtype release -Dprefix=/usr ..
	ninja -j $(nproc) install
	cd - >/dev/null
    rm -rf "$installLibdav1d_dir"
    if [ -f /usr/lib/$(gcc -dumpmachine)/libdav1d.so ] && [ ! -f /usr/lib/libdav1d.so ]; then
        ln -s /usr/lib/$(gcc -dumpmachine)/libdav1d.so /usr/lib/libdav1d.so
    fi
	ldconfig
    markPackagesAsInstalledByRegex '^(lib)?dav1d([0-9]|-dev)'
    pkg-config --list-all | grep -E '^(lib)?dav1d\s'
}

# Try to install libyuv.
#
# Arguments:
#   $1: the version to be installed
installLibyuv() {
    if ! isGccAtLeastVersion '4.9.3'; then
        echo 'libyuv not installed because gcc is too old' >&2
        return
    fi
    installAptPackages '^libjpeg[0-9]*-turbo' 'cmake ^libjpeg[0-9]*-turbo-dev'
    printf 'Downloading libyuv... '
    installLibyuv_dir="$(mktemp -d)"
	curl -ksSLf -o - https://chromium.googlesource.com/libyuv/libyuv/+archive/refs/heads/main.tar.gz | tar xzm -C "$installLibyuv_dir"
    printf 'done.\n'
	mkdir "$installLibyuv_dir/build"
	cd "$installLibyuv_dir/build"
    printf '\nconfigure_file(imaginepatch-libyuv.pc.in imaginepatch-libyuv.pc @ONLY)\n' >>../CMakeLists.txt
    cat <<'EOT' >../imaginepatch-libyuv.pc.in
prefix=@CMAKE_INSTALL_PREFIX@
exec_prefix=${prefix}
includedir=${prefix}/include
libdir=${prefix}/lib

Name: @CPACK_PACKAGE_NAME@
Description: @CPACK_PACKAGE_DESCRIPTION@
Version: @CPACK_PACKAGE_VERSION@
Requires: @pc_req_public@
Requires.private: @pc_req_private@
Cflags: -I${includedir}
Libs: -L${libdir} -llibyuv
EOT
	cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -B. ..
	make -j$(nproc) install
    ldconfig
    if ! pkg-config --exists libyuv && ! pkg-config --exists yuv; then
        cp imaginepatch-libyuv.pc /usr/lib/pkgconfig/libyuv.pc
        ldconfig
    fi
	cd - >/dev/null
    rm -rf "$installLibyuv_dir"
	ldconfig
    markPackagesAsInstalledByRegex '^(lib)?yuv([0-9]|-dev)'
    pkg-config --list-all | grep -E '^(lib)?yuv\s'
}

# Try to install libavif.
#
# Arguments:
#   $1: the version to be installed
installLibavif() {
    if ! pkg-config --list-all | grep -E '^(lib)?aom\s' >/dev/null; then
        echo 'libavif not installed because libaom is not installed' >&2
        return
    fi
    if ! isCMakeAtLeastVersion '3.5'; then
        echo 'libavif not installed because cmake is too old' >&2
        return
    fi
    installAptPackages '' 'cmake'
    printf 'Downloading libavif v%s... ' "$1"
    installLibavif_dir="$(mktemp -d)"
    curl -ksSLf -o - https://codeload.github.com/AOMediaCodec/libavif/tar.gz/refs/tags/v$1 | tar xzm -C "$installLibavif_dir"
    printf 'done.\n'
    mkdir "$installLibavif_dir/libavif-$1/build"
	cd "$installLibavif_dir/libavif-$1/build"
	cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DAVIF_CODEC_AOM=ON -DCMAKE_INSTALL_LIBDIR:PATH=lib
	make -j$(nproc) install
	cd - >/dev/null
    rm -rf "$installLibavif_dir"
	ldconfig
    markPackagesAsInstalledByRegex '^(lib)?avif([0-9]|-dev)'
    pkg-config --list-all | grep -E '^(lib)?avif\s'
}

# Install libde265.
#
# Arguments:
#   $1: the version to be installed
#
# @todo:
# configure: WARNING: Did not find libvideogfx or libsdl, video output of dec265 will be disabled.
# configure: WARNING: Did not find libvideogfx or libswscale, compilation of sherlock265 will be disabled.
installLibde265() {
    installAptPackages '' 'automake libtool'
    printf 'Downloading libde265 v%s... ' "$1"
    installLibde265_dir="$(mktemp -d)"
    curl -ksSLf -o - https://github.com/strukturag/libde265/releases/download/v$1/libde265-$1.tar.gz | tar xzm -C "$installLibde265_dir"
    printf 'done.\n'
    cd "$installLibde265_dir/libde265-$1"
    autoreconf -f -i
    ./configure
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installLibde265_dir"
    ldconfig
    markPackagesAsInstalledByRegex '^(lib)?de265'
    pkg-config --list-all | grep -E '^(lib)?de265\s'
}

# Install libheif.
#
# Arguments:
#   $1: the version to be installed
installLibheif() {
    installAptPackages '^libjpeg[0-9]*-turbo ^libpng[0-9\-]*$' 'automake libtool ^libjpeg[0-9]*-turbo-dev libpng-dev'
    printf 'Downloading libheif v%s... ' "$1"
    installLibheif_dir="$(mktemp -d)"
    curl -ksSLf -o - https://github.com/strukturag/libheif/releases/download/v$1/libheif-$1.tar.gz | tar xzm -C "$installLibheif_dir"
    printf 'done.\n'
    cd "$installLibheif_dir/libheif-$1"
    autoreconf -f -i
    ./configure --disable-examples
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installLibheif_dir"
    ldconfig
    markPackagesAsInstalledByRegex '^libheif.*'
    pkg-config --list-all | grep -E '^(lib)?heif\s'
}

# Install GraphicsMagick.
#
# Arguments:
#   $1: the version to be installed
installGraphicsmagick() {
    if grep -Eq 'PRETTY_NAME.*jessie' /etc/os-release; then
        installGraphicsmagick_zstd=''
        installGraphicsmagick_zstdDev=''
    else
        installGraphicsmagick_zstd='^libzstd[0-9]*$'
        installGraphicsmagick_zstdDev='^libzstd[0-9]*-dev$'
    fi
    installAptPackages \
        "^libz[0-9\-]*$ ^libjpeg[0-9]*-turbo ^libpng[0-9\-]*$ ^libjbig[0-9\-]*$ ^libtiff[0-9]*$ ^libwebp[0-9]*$ ^libwebpdemux[0-9]*$ ^libwebpmux[0-9]*$ libxml2 ^liblcms2[0-9\-]*$ ^libfreetype[0-9]*$ $installGraphicsmagick_zstd" \
        "libbz2-dev ^libjpeg[0-9]*-turbo-dev libpng-dev libjbig-dev libtiff-dev libwebp-dev libxml2-dev liblcms2-dev ^libfreetype[0-9]*-dev$ $installGraphicsmagick_zstdDev"
    printf 'Downloading GraphicsMagick v%s... ' "$1"
    installGraphicsmagick_dir="$(mktemp -d)"
    curl -ksSLf -o - http://ftp.icm.edu.pl/pub/unix/graphics/GraphicsMagick/${1%.*}/GraphicsMagick-$1.tar.gz | tar xzm -C "$installGraphicsmagick_dir"
    printf 'done.\n'
    cd "$installGraphicsmagick_dir/GraphicsMagick-$1"
    CFLAGS='-Wno-misleading-indentation -Wno-unused-const-variable -Wno-pointer-compare -Wno-tautological-compare' ./configure --enable-shared
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installGraphicsmagick_dir"
    ldconfig
    markPackagesAsInstalledByRegex '^(lib)?graphicsmagick'
}

# Install ImageMagick.
#
# Arguments:
#   $1: the version to be installed
installImagemagick() {
    if grep -Eq 'PRETTY_NAME.*jessie' /etc/os-release; then
        installImagemagick_zstd=''
        installImagemagick_zstdDev=''
    else
        installImagemagick_zstd='^libzstd[0-9]*$'
        installImagemagick_zstdDev='^libzstd[0-9]*-dev$'
    fi
    installAptPackages \
        "^libz[0-9\-]*$ ^libjpeg[0-9]*-turbo ^libpng[0-9\-]*$ ^libjbig[0-9\-]*$ ^libtiff[0-9]*$ ^libwebp[0-9]*$ ^libwebpdemux[0-9]*$ ^libwebpmux[0-9]*$ libxml2 ^liblcms2[0-9\-]*$ ^libfreetype[0-9]*$ $installImagemagick_zstd ^libopenjp2[0-9\-]*$ ^libdjvulibre[0-9]*$ ^libwmf[0-9\.\-]*$ ^libfontconfig[0-9]*$ ^libzip[0-9]*$" \
        "libbz2-dev ^libjpeg[0-9]*-turbo-dev libpng-dev libjbig-dev libtiff-dev libwebp-dev libxml2-dev liblcms2-dev ^libfreetype[0-9]*-dev$ $installImagemagick_zstdDev ^libopenjp2[0-9\-]*-dev$ libdjvulibre-dev libwmf-dev libfontconfig-dev libzip-dev"
    installImagemagick_dir="$(mktemp -d)"
    printf 'Downloading ImageMagick v%s... ' "$1"
    curl -ksSLf -o - https://www.imagemagick.org/download/releases/ImageMagick-$1.tar.xz | tar xJm -C "$installImagemagick_dir"
    printf 'done.\n'
    cd "$installImagemagick_dir/ImageMagick-$1"
    ./configure --disable-docs
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installImagemagick_dir"
    ldconfig
    markPackagesAsInstalledByRegex '^(libmagickcore|libmagickwand|imagemagick)'
}

if grep -Eq 'PRETTY_NAME.*jessie' /etc/os-release; then
    # https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1332440
    ulimit -n 10000 2>/dev/null || true
fi

case "$1" in
    git)
        installGit "$2"
        ;;
    libaom)
        installLibaom "$2"
        ;;
    libdav1d)
        installLibdav1d "$2"
        ;;
    libyuv)
        installLibyuv
        ;;
    libavif)
        installLibavif "$2"
        ;;
    libde265)
        installLibde265 "$2"
        ;;
    libheif)
        installLibheif "$2"
        ;;
    graphicsmagick)
        installGraphicsmagick "$2"
        ;;
    imagemagick)
        installImagemagick "$2"
        ;;
    cleanup)
        uninstallAptDevPackages
        rm -rf /var/lib/apt/lists/*
        ;;
    final-cleanup)
        uninstallAptDevPackages
        rm -rf /var/lib/apt/lists/*
        rm -rf /tmp/*
        unlink "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/utilities.sh"
        unlink "$0"
        ;;
    *)
        printf 'Unrecognized command: "%s"\n' "$1">&2
        exit 1
esac
