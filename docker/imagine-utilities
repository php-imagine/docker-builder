APT_DEV_PACKAGES_FILE=/tmp/apt-dev-packages.txt

# Reset the IFS variable to its default value
resetIFS() {
    IFS='
	 '
}

# Check if a string is contained in a list
#
# Arguments:
#   $1: the string
#   $2: the list
#
# Return:
#   0: true
#   1: false
stringInList() {
    for stringInList_listItem in $2; do
        if [ "$1" = "$stringInList_listItem" ]; then
            return 0
        fi
    done
    return 1
}

# Check if a version is at least the requred one
# Both versions can be in the following formats:
#  - <mayor>
#  - <mayor>.<minor>
#  - <mayor>.<minor>.<patch>
#
# Arguments:
#   $1: the actual version
#   $2: the minimum required version
#
# Return:
#   0: true
#   1: false
isAtLeastVersion() {
    if [ -z "$1" ]; then
        return 1
    fi
    isAtLeastVersion_actual=$(printf '%s' "$1" | cut -d. -f1)
    isAtLeastVersion_wanted=$(printf '%s' "$2" | cut -d. -f1)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    if [ $isAtLeastVersion_actual -gt $isAtLeastVersion_wanted ]; then
        return 0
    fi
    isAtLeastVersion_actual=$(printf '%s' "$1.0" | cut -d. -f2)
    isAtLeastVersion_wanted=$(printf '%s' "$2.0" | cut -d. -f2)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    if [ $isAtLeastVersion_actual -gt $isAtLeastVersion_wanted ]; then
        return 0
    fi
    isAtLeastVersion_actual=$(printf '%s' "$1.0.0" | cut -d. -f3)
    isAtLeastVersion_wanted=$(printf '%s' "$2.0.0" | cut -d. -f3)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    return 0
}

# Check if thencmake version is at least the requred one
# The version can be in the following formats:
#  - <mayor>
#  - <mayor>.<minor>
#  - <mayor>.<minor>.<patch>
#
# Arguments:
#   $1: the minimum required version
#
# Return:
#   0: true
#   1: false
isCMakeAtLeastVersion() {
    if command -v cmake >/dev/null 2>/dev/null; then
        isCMakeAtLeastVersion_version="$(cmake --version | head -n1 | sed -E 's/^.*[^0-9]([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    else
        isCMakeAtLeastVersion_version="$(getAptPackageAvailableVersion cmake)"
    fi
    if isAtLeastVersion "$isCMakeAtLeastVersion_version" "$1"; then
        return 0
    fi
    return 1
}

# Check if then meson version is at least the requred one
# The version can be in the following formats:
#  - <mayor>
#  - <mayor>.<minor>
#  - <mayor>.<minor>.<patch>
#
# Arguments:
#   $1: the minimum required version
#
# Return:
#   0: true
#   1: false
isMesonAtLeastVersion() {
    if command -v meson >/dev/null 2>/dev/null; then
        isMesonAtLeastVersion_version="$(meson --version 2>/dev/null | grep -vE '^WARNING')"
    else
        isMesonAtLeastVersion_version="$(getAptPackageAvailableVersion meson)"
    fi
    if isAtLeastVersion "$isMesonAtLeastVersion_version" "$1"; then
        return 0
    fi
    return 1
}

# Check if then gcc version is at least the requred one
# The version can be in the following formats:
#  - <mayor>
#  - <mayor>.<minor>
#  - <mayor>.<minor>.<patch>
#
# Arguments:
#   $1: the minimum required version
#
# Return:
#   0: true
#   1: false
isGccAtLeastVersion() {
    isGccAtLeastVersion_installed="$(gcc --version | head -n1 | sed -E 's/^.*[^0-9]([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if isAtLeastVersion "$isGccAtLeastVersion_installed" "$1"; then
        return 0
    fi
    return 1
}

# Get the version of an apt package.
#
# Arguments:
#   $1: the package name (regex, without leading '^' or trailing '$')
#
# Output:
#   the version (in format <mayor>.<minor>.<patch> or <mayor>.<minor>)
#   outputs nothing if the package can't be found
getAptPackageAvailableVersion() {
    getAptPackageAvailableVersion_found="$(apt-cache show "^$1$" 2>/dev/null || true)"
    if [ -z "$getAptPackageAvailableVersion_found" ]; then
        return
    fi
    printf '%s' "$getAptPackageAvailableVersion_found" | grep -E '^Version: ' | head -n1 | sed -E 's/^.*[^0-9\.]([0-9]+\.[0-9]+(\.[0-9]+)?).*$/\1/'
}

# Check if the version of an apt package is at least the provided one.
#
# Arguments:
#   $1: the package name (regex, without leading '^' or trailing '$')
#   $2: the minimum required version (in format <mayor>.<minor>.<patch>, <mayor>.<minor>, or <mayor>)
isAptPackageAtLeastVersion() {
    if isAtLeastVersion "$(getAptPackageAvailableVersion "$1")" "$2"; then
        return 0
    fi
    return 1
}

# Mark apt-packages as already installed
#
# Arguments:
#   $1: a regex to identify the the packages (you may want to use a leading '^' or a trailing '$')
markPackagesAsInstalledByRegex() {
    markPackagesAsInstalledByRegex_names=''
    IFS='
'
    for markPackagesAsInstalledByRegex_item in $(apt-cache search --names-only "^$1"); do
        markPackagesAsInstalledByRegex_names="$markPackagesAsInstalledByRegex_names $(printf '%s' "$markPackagesAsInstalledByRegex_item" | cut -d' ' -f1)"
    done
    resetIFS
    markPackagesAsInstalledByRegex_names="${markPackagesAsInstalledByRegex_names# }"
    if [ -z "$markPackagesAsInstalledByRegex_names" ]; then
        printf 'No packages marked as manually installed: none found for "%s"\n' "$1"
    else
        for markPackagesAsInstalledByRegex_item in $markPackagesAsInstalledByRegex_names; do
            markPackagesAsInstalledByName "$markPackagesAsInstalledByRegex_item"
        done
    fi
}

# Mark an apt-package as already installed
#
# Arguments:
#   $1: the apt package name
markPackagesAsInstalledByName() {
    installAptPackages '' 'equivs'
    printf 'Marking the apt package "%s" as manually installed\n' "$1"
    printf -- '- looking for the version provided by apt... '
    markPackagesAsInstalledByName_candidateVersion="$(apt-cache policy "$1" | grep 'Candidate: ' | sed -E 's/^\s+//' | cut -d' ' -f2)"
    printf '%s\n' "$markPackagesAsInstalledByName_candidateVersion"
    printf -- '- creating ctl file...'
    markPackagesAsInstalledByName_dir="$(mktemp -d)"
    cd "$markPackagesAsInstalledByName_dir"
    printf '' >package.ctl
    printf 'Package: %s\n' "$1" >>package.ctl
    printf 'Standards-Version: %s\n' "$markPackagesAsInstalledByName_candidateVersion" >>package.ctl
    printf 'Version: %s\n' "$markPackagesAsInstalledByName_candidateVersion" >>package.ctl
    printf 'done.\n'
    printf -- '- creating deb file...'
    if ! equivs-build package.ctl >temp.log 2>&1; then
        cat temp.log >&2
        return 1
    fi
    printf 'done.\n'
    printf -- '- installing deb file...'
    if ! dpkg -i *.deb >temp.log 2>&1; then
        cat temp.log >&2
        return 1
    fi
    printf 'done.\n'
    cd - >/dev/null
    rm -rf "$markPackagesAsInstalledByName_dir"
    #apt-mark hold "$1"
}

# Install apt packages
#
# Arguments:
#   $1: space-separated list of apt packages to be kept when the image will be ready
#   $1: space-separated list of apt packages to be used only at build time (will be removed at the end)
installAptPackages() {
    installAptPackages_alldev=''
    if [ -f "$APT_DEV_PACKAGES_FILE" ]; then
        installAptPackages_alldev="$(cat "$APT_DEV_PACKAGES_FILE")"
    fi
    installAptPackages_new=''
    if [ -n "${2:-}" ]; then
        for installAptPackages_req in $2; do
            if [ -z "$installAptPackages_alldev" ]; then
                installAptPackages_alldev="$installAptPackages_req"
                installAptPackages_new="$installAptPackages_req"
            elif ! stringInList "$installAptPackages_req" "$installAptPackages_alldev"; then
                installAptPackages_alldev="$installAptPackages_alldev $installAptPackages_req"
                installAptPackages_new="$installAptPackages_new $installAptPackages_req"
            fi
        done
    fi
    if [ -n "${1:-}" ]; then
        installAptPackages_new="$installAptPackages_new $1"
    fi
    if [ -z "$installAptPackages_new" ]; then
        return 0
    fi
    apt-get install -qy --no-install-recommends $installAptPackages_new
    printf '%s' "$installAptPackages_alldev" >"$APT_DEV_PACKAGES_FILE"
}

# Uninstall the apt packages installed only for build time.
uninstallAptDevPackages() {
    if [ ! -f "$APT_DEV_PACKAGES_FILE" ]; then
        return 0
    fi
    apt-get remove -qy --purge $(cat "$APT_DEV_PACKAGES_FILE")
    unlink "$APT_DEV_PACKAGES_FILE"
}
