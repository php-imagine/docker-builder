#!/bin/sh

set -o nounset
set -o errexit

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

installLibaom() {
    printf 'Downloading libaom v%s... ' "$LIBAOM_VERSION"
    installLibaom_dir="$(mktemp -d)"
    curl -ksSLf -o - https://aomedia.googlesource.com/aom/+archive/v$LIBAOM_VERSION.tar.gz | tar xzm -C "$installLibaom_dir"
    printf 'done.\n'
	mkdir "$installLibaom_dir/my.build"
	cd "$installLibaom_dir/my.build"
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0 -DCMAKE_INSTALL_LIBDIR:PATH=lib ..
	ninja -j $(nproc) install
	cd - >/dev/null
    rm -rf "$installLibaom_dir"
	ldconfig
}

installLibdav1d() {
    printf 'Downloading libdav1d v%s... ' "$LIBDAV1D_VERSION"
    installLibdav1d_dir="$(mktemp -d)"
    curl -ksSLf -o - https://code.videolan.org/videolan/dav1d/-/archive/$LIBDAV1D_VERSION/dav1d-$LIBDAV1D_VERSION.tar.gz | tar xzm -C "$installLibdav1d_dir"
    printf 'done.\n'
    mkdir "$installLibdav1d_dir/dav1d-$LIBDAV1D_VERSION/build"
	cd "$installLibdav1d_dir/dav1d-$LIBDAV1D_VERSION/build"
	meson --buildtype release -Dprefix=/usr ..
	ninja -j $(nproc) install
	cd - >/dev/null
    rm -rf "$installLibdav1d_dir"
    if [ -f /usr/lib/$(gcc -dumpmachine)/libdav1d.so ] && ! [ -f /usr/lib/libdav1d.so ]; then
        ln -s /usr/lib/$(gcc -dumpmachine)/libdav1d.so /usr/lib/libdav1d.so
    fi
	ldconfig
}

installLibyuv() {
    printf 'Downloading libyuv... '
    installLibyuv_dir="$(mktemp -d)"
	curl -ksSLf -o - https://chromium.googlesource.com/libyuv/libyuv/+archive/refs/heads/main.tar.gz | tar xzm -C "$installLibyuv_dir"
    printf 'done.\n'
	mkdir "$installLibyuv_dir/build"
	cd "$installLibyuv_dir/build"
	cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -B. ..
	make -j$(nproc) install
	cd - >/dev/null
    rm -rf "$installLibyuv_dir"
	ldconfig
}

installLibavif() {
    printf 'Downloading libavif v%s... ' "$LIBAVIF_VERSION"
    installLibavif_dir="$(mktemp -d)"
    curl -ksSLf -o - https://codeload.github.com/AOMediaCodec/libavif/tar.gz/refs/tags/v$LIBAVIF_VERSION | tar xzm -C "$installLibavif_dir"
    printf 'done.\n'
    mkdir "$installLibavif_dir/libavif-$LIBAVIF_VERSION/build"
	cd "$installLibavif_dir/libavif-$LIBAVIF_VERSION/build"
	cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DAVIF_CODEC_AOM=ON -DCMAKE_INSTALL_LIBDIR:PATH=lib
	make -j$(nproc) install
	cd - >/dev/null
    rm -rf "$installLibavif_dir"
	ldconfig
}

if grep -Eq 'PRETTY_NAME.*jessie' /etc/os-release; then
    # https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1332440
    ulimit -n 10000
fi

# Update system packages
IMAGINE_COMPILETIME_PACKAGES="
    cmake
    automake
    libtool
    nasm
    meson
    equivs
    ^libjpeg[0-9]*-turbo-dev$
    libtiff-dev
    libwebp-dev
    libpng-dev
    ^libfreetype[0-9]*-dev$
    libwmf-dev
    liblcms2-dev
    libxml2-dev
    libbz2-dev
    libxpm-dev
    libvpx-dev
"
IMAGINE_RUNTIME_PACKAGES="
    git
    ^libjpeg[0-9]*-turbo$
    ^libtiff[0-9]*$
    ^libwebp[0-9]*$
    ^libwebpdemux[0-9]*$
    ^libwebpmux[0-9]*$
    ^libpng[0-9\-]*$
    ^libfreetype[0-9\-]*$
    ^libwmf[0-9\.\-]*$
    ^liblcms2-[0-9]+$
    libxml2
    ^libbz2[0-9\-]*$
    libxpm4
    ^libvpx[0-9]+$
    ^libxext[0-9]+$
"
if [ -n "$(apt-cache search --names-only '^libzstd-dev$')" ]; then
    IMAGINE_COMPILETIME_PACKAGES="$IMAGINE_COMPILETIME_PACKAGES libzstd-dev"
fi

apt-get -q update
apt-get -q upgrade -y
apt-get -q install -y --no-install-recommends $IMAGINE_COMPILETIME_PACKAGES $IMAGINE_RUNTIME_PACKAGES

if isCMakeAtLeastVersion '3.6'; then
    installLibaom
else
    echo 'libaom not installed because cmake is too old'
fi
if isMesonAtLeastVersion '0.44'; then
    installLibdav1d
else
    echo 'libdav1d not installed because meson is too old'
fi
if isGccAtLeastVersion '4.9.3'; then
    installLibyuv
else
    echo 'libyuv not installed because gcc is too old'
fi
if isCMakeAtLeastVersion '3.5'; then
    installLibavif
else
    echo 'libavif not installed because cmake is too old'
fi

# Install install-php-extensions
curl -sSLf \
    -o /usr/local/bin/install-php-extensions \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions
chmod +x /usr/local/bin/install-php-extensions

# Install composer
IPE_KEEP_SYSPKG_CACHE=1 install-php-extensions @composer-2

printf '#!/bin/sh\napt-get remove -qy --purge %s\napt-get clean\nunlink "$0"\n' "$(printf '%s' "$IMAGINE_COMPILETIME_PACKAGES" | tr '\n' ' ')" >/cleanup.sh
chmod +x /cleanup.sh

apt-get clean
if [ "${1:-}" = --cleanup ]; then
    unlink -- "$0"
fi
