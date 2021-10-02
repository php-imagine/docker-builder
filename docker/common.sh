resetIFS() {
    IFS='
	 '
}

isAtLeastVersion() {
    isAtLeastVersion_actual=$(printf '%s' "$1" | cut -d. -f1)
    isAtLeastVersion_wanted=$(printf '%s' "$2" | cut -d. -f1)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    isAtLeastVersion_actual=$(printf '%s' "$1.0" | cut -d. -f2)
    isAtLeastVersion_wanted=$(printf '%s' "$2.0" | cut -d. -f2)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    isAtLeastVersion_actual=$(printf '%s' "$1.0.0" | cut -d. -f3)
    isAtLeastVersion_wanted=$(printf '%s' "$2.0.0" | cut -d. -f3)
    if [ $isAtLeastVersion_actual -lt $isAtLeastVersion_wanted ]; then
        return 1
    fi
    return 0
}

isCMakeAtLeastVersion() {
    isCMakeAtLeastVersion_installed="$(cmake --version | head -n1 | sed -E 's/^.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if isAtLeastVersion "$isCMakeAtLeastVersion_installed" "$1"; then
        return 0
    fi
    return 1
}

isMesonAtLeastVersion() {
    isMesonAtLeastVersion_installed="$(meson --version 2>/dev/null | grep -vE '^WARNING')"
    if isAtLeastVersion "$isMesonAtLeastVersion_installed" "$1"; then
        return 0
    fi
    return 1
}

isGccAtLeastVersion() {
    isGccAtLeastVersion_installed="$(gcc --version | head -n1 | sed -E 's/^.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if isAtLeastVersion "$isGccAtLeastVersion_installed" "$1"; then
        return 0
    fi
    return 1
}

markPackagesAsInstalledByRegex() {
    markPackagesAsInstalledByRegex_names=''
    IFS='
'
    for markPackagesAsInstalledByRegex_item in $(apt-cache search --names-only "^$1"); do
        markPackagesAsInstalledByRegex_names="$markPackagesAsInstalledByRegex_names $(printf '%s' "$markPackagesAsInstalledByRegex_item" | cut -d' ' -f1)"
    done
    resetIFS
    markPackagesAsInstalledByRegex_names="${markPackagesAsInstalledByRegex_names# }"
    if test -z "$markPackagesAsInstalledByRegex_names"; then
        printf 'No packages marked as manually installed: none found for "%s"\n' "$1"
    else
        for markPackagesAsInstalledByRegex_item in $markPackagesAsInstalledByRegex_names; do
            markPackagesAsInstalledByName "$markPackagesAsInstalledByRegex_item"
        done
    fi
}

markPackagesAsInstalledByName() {
    markPackagesAsInstalledByName_candidateVersion="$(apt-cache policy "$1" | grep 'Candidate: ')"
    markPackagesAsInstalledByName_candidateVersion="$(printf '%s' "$markPackagesAsInstalledByName_candidateVersion" | sed -E 's/^\s+//' | cut -d' ' -f2)"
    markPackagesAsInstalledByName_dir="$(mktemp -d)"
    cd "$markPackagesAsInstalledByName_dir"
    printf '' >package.ctl
    printf 'Package: %s\n' "$1" >>package.ctl
    printf 'Standards-Version: %s\n' "$markPackagesAsInstalledByName_candidateVersion" >>package.ctl
    printf 'Version: %s\n' "$markPackagesAsInstalledByName_candidateVersion" >>package.ctl
    if ! equivs-build package.ctl >equivs.log 2>&1; then
        cat equivs.log
        return 1
    fi
    dpkg -i *.deb
    cd - >/dev/null
    rm -rf "$markPackagesAsInstalledByName_dir"
    #apt-mark hold "$1"
}
