#!/bin/sh

set -o nounset
set -o errexit

. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

shouldInstallPHPExtension() {
    case "-$EXTENSIONS-" in
        *-$1-*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

installGraphicsMagick() {
    printf 'Downloading GraphicsMagick v%s... ' "$GRAPHICSMAGIC_VERSION"
    installGraphicsMagick_majorminor="${GRAPHICSMAGIC_VERSION%.*}"
    installGraphicsMagick_dir="$(mktemp -d)"
    curl -ksSLf -o - http://ftp.icm.edu.pl/pub/unix/graphics/GraphicsMagick/$installGraphicsMagick_majorminor/GraphicsMagick-$GRAPHICSMAGIC_VERSION.tar.gz | tar xzm -C "$installGraphicsMagick_dir"
    printf 'done.\n'
    cd "$installGraphicsMagick_dir/GraphicsMagick-$GRAPHICSMAGIC_VERSION"
    CFLAGS='-Wno-misleading-indentation -Wno-unused-const-variable -Wno-pointer-compare -Wno-tautological-compare' ./configure --enable-shared
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installGraphicsMagick_dir"
    ldconfig
    markPackagesAsInstalledByRegex 'libgraphicsmagick.*'
}

installImageMagick() {
    installImageMagick_major=$(printf %s "$IMAGEMAGICK_VERSION" | sed -E 's/^([0-9+]).*$/\1/')
    if [ $installImageMagick_major -ge 7 ]; then
        if ! pkg-config --exists libde265; then
            printf 'Downloading libde265 v%s... ' "$LIBDE265_VERSION"
            installImageMagick_dir="$(mktemp -d)"
            curl -ksSLf -o - https://github.com/strukturag/libde265/releases/download/v$LIBDE265_VERSION/libde265-$LIBDE265_VERSION.tar.gz | tar xzm -C "$installImageMagick_dir"
            printf 'done.\n'
            cd "$installImageMagick_dir/libde265-$LIBDE265_VERSION"
            autoreconf -f -i
            ./configure
            make V=0 -j$(nproc) install
            cd - >/dev/null
            rm -rf "$installImageMagick_dir"
            markPackagesAsInstalledByRegex 'libde265.*'
        fi
        if ! pkg-config --exists libheif; then
            printf 'Downloading libheif v%s... ' "$LIBHEIF_VERSION"
            installImageMagick_dir="$(mktemp -d)"
            curl -ksSLf -o - https://github.com/strukturag/libheif/releases/download/v$LIBHEIF_VERSION/libheif-$LIBHEIF_VERSION.tar.gz | tar xzm -C "$installImageMagick_dir"
            printf 'done.\n'
            cd "$installImageMagick_dir/libheif-$LIBHEIF_VERSION"
            autoreconf -f -i
            ./configure
            make V=0 -j$(nproc) install
            cd - >/dev/null
            rm -rf "$installImageMagick_dir"
            markPackagesAsInstalledByRegex 'libheif.*'
        fi
    fi
    installImageMagick_dir="$(mktemp -d)"
    printf 'Downloading ImageMagick v%s... ' "$IMAGEMAGICK_VERSION"
    curl -ksSLf -o - https://www.imagemagick.org/download/releases/ImageMagick-$IMAGEMAGICK_VERSION.tar.xz | tar xJm -C "$installImageMagick_dir"
    printf 'done.\n'
    cd "$installImageMagick_dir/ImageMagick-$IMAGEMAGICK_VERSION"
    ./configure --disable-docs
    make V=0 -j$(nproc) install
    cd - >/dev/null
    rm -rf "$installImageMagick_dir"
    ldconfig
    markPackagesAsInstalledByRegex 'libmagick(core|wand).*'
}

if shouldInstallPHPExtension gmagick; then
    installGraphicsMagick
fi

if shouldInstallPHPExtension imagick; then
    installImageMagick
fi

install-php-extensions $(printf '%s' "$EXTENSIONS" | tr -- '-' ' ')

/cleanup.sh

# Check that everything works
IFS='-'
for EXTENSION in $EXTENSIONS; do
    php --ri $EXTENSION
done
resetIFS

if [ "${1:-}" = --cleanup ]; then
    unlink -- "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"
    unlink -- "$0"
fi
