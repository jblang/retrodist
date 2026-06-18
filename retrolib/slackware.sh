# shellcheck shell=bash
# Slackware-specific install media and tagfile preparation helpers.

# Per-invocation cache for the ISO package listing; set by slackware_ensure_pkglist().
SLACKWARE_PKGLIST=

# Space-separated *.tag stems to apply at install time (default: full).
INSTALL_TAGSETS=${INSTALL_TAGSETS:-full}

# Copies each disk's tagfile and description files (disk*, *.txt) from srcroot
# into its series' first disk, tagroot/<series>1; tagfile.org lands as tagfile.
slackware_consolidate_tagfiles() {
    local srcroot=$1 tagroot=$2 src fname diskdir firstdir
    find "$srcroot" -mindepth 2 -maxdepth 2 -type f \
        \( -name 'tagfile' -o -name 'tagfile.org' -o -name 'disk*' -o -name '*.txt' \) |
        while IFS= read -r src; do
            fname=$(basename "$src")
            [[ "$fname" == "tagfile.org" ]] && fname="tagfile"
            diskdir=$(basename "$(dirname "$src")")
            firstdir="$(printf '%s' "$diskdir" | sed 's/[0-9][0-9]*$//')1"
            mkdir -p "$tagroot/$firstdir"
            cp "$src" "$tagroot/$firstdir/$fname"
        done
}

# Extracts the tagfile/description sources for default.tag into tagroot, from
# staged FAT packages if present, otherwise from an install ISO.
slackware_extract_tagfiles() {
    local tagroot=$1
    local pkgroot

    rm -rf "$tagroot"
    mkdir -p "$tagroot"

    if pkgroot=$(slackware_staged_pkg_root); then
        slackware_consolidate_tagfiles "$pkgroot" "$tagroot"
    elif [[ -f install.iso ]]; then
        slackware_extract_tagfiles_from_iso install.iso "$tagroot"
    elif [[ -f "$ORIGDIR/disc1.iso" ]]; then
        slackware_extract_tagfiles_from_iso "$ORIGDIR/disc1.iso" "$tagroot"
    fi
}

# Extracts an ISO's tagfile and disk*/*.txt members into tagroot, using the
# cached package listing to locate them, then consolidates them.
slackware_extract_tagfiles_from_iso() {
    local iso=$1 tagroot=$2
    local pathroot tmpdir

    # ensure_pkglist must run in this shell, not a subshell, so SLACKWARE_PKGLIST persists.
    slackware_ensure_pkglist "$iso" || return
    pathroot=$(awk -F/ 'NF { print $1; exit }' "$SLACKWARE_PKGLIST")
    [[ -n "$pathroot" ]] || return
    tmpdir=$TEMPDIR/tagfile-extract
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"
    7z x -y -o"$tmpdir" "$iso" "$pathroot/*/tagfile" "$pathroot/*/disk*" "$pathroot/*/*.txt" >/dev/null 2>&1 || true
    if [[ -d "$tmpdir/$pathroot" ]]; then
        slackware_consolidate_tagfiles "$tmpdir/$pathroot" "$tagroot"
    fi
    rm -rf "$tmpdir"
}

# Emits the staged-package universe as "target<TAB>series<TAB>pkg" lines (pkg
# version-stripped), targeting each series' first-disk tagfile and tagfile.new.
slackware_universe_from_staged() {
    local pkgroot=$1 series firstdir seriesdir
    find "$pkgroot" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r seriesdir; do
        basename "$seriesdir" | sed 's/[0-9][0-9]*$//'
    done | sort -u | while IFS= read -r series; do
        [[ -n "$series" ]] || continue
        firstdir=$(find "$pkgroot" -mindepth 1 -maxdepth 1 -type d -name "${series}[0-9]*" | sort | head -n 1)
        [[ -n "$firstdir" ]] || continue
        find "$pkgroot" -mindepth 1 -maxdepth 1 -type d -name "${series}[0-9]*" | while IFS= read -r seriesdir; do
            find "$seriesdir" -maxdepth 1 -type f \( -name '*.tgz' -o -name '*.tar' \)
        done | awk -v fd="$firstdir" -v series="$series" '
            { pkg = $0; sub(/.*\//, "", pkg); sub(/\.(tgz|tar)$/, "", pkg)
              n = split(pkg, a, /-/)
              if (n > 3) { o = a[1]; for (i = 2; i <= n - 3; i++) o = o "-" a[i]; pkg = o }
              print fd "/tagfile"     "\t" series "\t" pkg
              print fd "/tagfile.new" "\t" series "\t" pkg }'
    done
}

# Finds the staged Slackware package root on FAT media.
slackware_staged_pkg_root() {
    local root
    for root in fat/packages fat; do
        if [[ -d "$root" ]] && find "$root" -mindepth 2 -maxdepth 2 -type f \( -name '*.tgz' -o -name '*.tar' \) 2>/dev/null | grep -q .; then
            printf '%s\n' "$root"
            return 0
        fi
    done
    return 1
}

# Lists the ISO's package paths once into $TEMPDIR, caching the path in
# SLACKWARE_PKGLIST for reuse; returns 1 if no packages are found.
slackware_ensure_pkglist() {
    local iso=$1

    if [[ -n "${SLACKWARE_PKGLIST:-}" && -f "$SLACKWARE_PKGLIST" ]]; then
        return 0
    fi

    local root ext tmplist=$TEMPDIR/packages.txt
    : >"$tmplist"
    for root in slakware slackware; do
        for ext in tgz tar; do
            7z l "$iso" "$root/**/*.$ext" 2>/dev/null |
                awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} / && $6 ~ /\// { print $6 }' >>"$tmplist"
        done
        if [[ -s "$tmplist" ]]; then
            sort -u "$tmplist" -o "$tmplist"
            SLACKWARE_PKGLIST=$tmplist
            return 0
        fi
    done
    return 1
}

# Emits the ISO-package universe (from SLACKWARE_PKGLIST) as
# "target<TAB>series<TAB>pkg" lines, targeting each disk's fat/tagfiles tagfile.
slackware_universe_from_iso() {
    awk -F/ -v root=fat/tagfiles '
        NF >= 3 {
            disk = $(NF - 1); pkg = $NF
            sub(/\.(tgz|tar)$/, "", pkg)
            n = split(pkg, a, /-/)
            if (n > 3) { o = a[1]; for (i = 2; i <= n - 3; i++) o = o "-" a[i]; pkg = o }
            series = disk; sub(/[0-9]+$/, "", series)
            print root "/" disk "/tagfile" "\t" series "\t" pkg
        }
    ' "$SLACKWARE_PKGLIST"
}

# Collects *.tag from CONFDIR and parent into SLACKWARE_TAGSETS (CONFDIR shadows
# parent), then filters to stems listed in INSTALL_TAGSETS.
slackware_collect_tagsets() {
    local dir=$CONFDIR parent f name stem
    parent=$(dirname "$dir")
    SLACKWARE_TAGSETS=()

    for f in "$dir"/*.tag; do
        [[ -f "$f" ]] || continue
        SLACKWARE_TAGSETS+=("$f")
    done
    if [[ "$parent" != "$dir" ]]; then
        for f in "$parent"/*.tag; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f")
            [[ -f "$dir/$name" ]] && continue
            SLACKWARE_TAGSETS+=("$f")
        done
    fi

    local -a selected=()
    for f in "${SLACKWARE_TAGSETS[@]}"; do
        name=$(basename "$f"); stem="${name%.tag}"
        case " $INSTALL_TAGSETS " in *" $stem "*) selected+=("$f") ;; esac
    done
    SLACKWARE_TAGSETS=("${selected[@]}")
}

# Writes each install tagfile from the package universe (default SKP, overridden
# by *.tag wildcard then specific rules per INSTALL_TAGSETS) and fat/disksets.txt.
slackware_prepare_tagfiles() {
    local pkgroot universe=$TEMPDIR/tagfile-universe d
    local -a SLACKWARE_TAGSETS=()

    if pkgroot=$(slackware_staged_pkg_root); then
        slackware_universe_from_staged "$pkgroot" >"$universe"
    elif [[ -f install.iso ]]; then
        slackware_ensure_pkglist install.iso || return
        slackware_universe_from_iso >"$universe"
    elif [[ -f "$ORIGDIR/disc1.iso" ]]; then
        slackware_ensure_pkglist "$ORIGDIR/disc1.iso" || return
        slackware_universe_from_iso >"$universe"
    else
        return
    fi
    [[ -s "$universe" ]] || return

    # Sort (byte order for determinism) to group each target's lines so the awk
    # writes each in one pass, then create the target dirs.
    LC_ALL=C sort -u "$universe" -o "$universe"
    cut -f1 "$universe" | sed 's#/[^/]*$##' | sort -u | while IFS= read -r d; do
        mkdir -p "$d"
    done

    slackware_collect_tagsets
    awk -v rules="${SLACKWARE_TAGSETS[*]}" -v disksets=fat/disksets.txt '
        BEGIN {
            FS = "\t"
            n = split(rules, rf, " ")
            for (i = 1; i <= n; i++) {
                while ((getline line < rf[i]) > 0) {
                    gsub(/^[ \t]+/, "", line)
                    if (line == "" || line ~ /^#/) continue
                    if (split(line, a, /[ \t]+/) < 3) continue
                    if (a[3] !~ /^(ADD|REC|OPT|SKP)$/) continue
                    if (a[2] == "*") wild[a[1]] = a[3]
                    else spec[a[1], a[2]] = a[3]
                }
                close(rf[i])
            }
        }
        {
            target = $1; series = $2; pkg = $3
            if (target != cur) { if (cur != "") close(cur); cur = target }
            state = ((series, pkg) in spec) ? spec[series, pkg] : \
                    ((series in wild) ? wild[series] : "SKP")
            printf "%s:     %s\n", pkg, state > target
            if (state != "SKP") has_pkg[series] = 1
        }
        END {
            n = 0
            for (s in has_pkg) keys[++n] = s
            for (i = 1; i <= n; i++)
                for (j = i + 1; j <= n; j++)
                    if (keys[j] < keys[i]) { t = keys[i]; keys[i] = keys[j]; keys[j] = t }
            out = ""
            for (i = 1; i <= n; i++) out = out (i > 1 ? " " : "") keys[i]
            print out > disksets
        }
    ' <"$universe"

    sync
}

# Generates default.tag in outfile from tagroot's tagfile/description sources;
# skips silently when none are present (non-Slackware or pre-tagfile media).
slackware_generate_default_tag() {
    local tagroot=$1
    local outfile=$2

    find "$tagroot" -name tagfile -print -quit | grep -q . || return 0

    awk -v tagroot="$tagroot" '
        function sort_arr(arr, n,   i, j, t) {
            for (i = 1; i <= n; i++)
                for (j = i + 1; j <= n; j++)
                    if (arr[j] < arr[i]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
        }
        function load_series(s,   dir, f, line, key, val, cmd, n) {
            dir = tagroot "/" s "1"
            n = 0
            f = dir "/tagfile"
            while ((getline line < f) > 0) {
                if (line !~ /^[^: \t]+:[ \t]*(ADD|REC|OPT|SKP)([ \t]|$)/) continue
                key = line; sub(/:.*/, "", key)
                val = line; sub(/^[^:]*:[ \t]*/, "", val); sub(/[ \t].*$/, "", val)
                if (!(key in tag)) pkgs[++n] = key
                tag[key] = val
            }
            close(f)
            cmd = "ls " dir "/disk* " dir "/*.txt 2>/dev/null"
            while ((cmd | getline f) > 0) {
                while ((getline line < f) > 0) {
                    if (line ~ /^CONTENTS:/) continue
                    if (line !~ /^[^: \t]+:[ \t]*[^ \t]/) continue
                    key = line; sub(/:.*/, "", key)
                    val = line; sub(/^[^: \t]+:[ \t]*/, "", val); gsub(/[ \t]+$/, "", val)
                    if (!(key in desc)) desc[key] = val
                }
                close(f)
            }
            close(cmd)
            return n
        }
        BEGIN {
            cmd = "ls " tagroot "/*1/tagfile 2>/dev/null"
            ns = 0
            while ((cmd | getline f) > 0) {
                s = f; sub(/\/tagfile$/, "", s); sub(/.*\//, "", s); sub(/[0-9]+$/, "", s)
                if (s != "") serieslist[++ns] = s
            }
            close(cmd)
            sort_arr(serieslist, ns)
            for (si = 1; si <= ns; si++) {
                s = serieslist[si]
                delete pkgs; delete tag; delete desc
                m = load_series(s)
                sort_arr(pkgs, m)
                if (si > 1) printf "\n"
                printf "%-4s %-12s %s\n", s, "*", "SKP"
                for (k = 1; k <= m; k++) {
                    p = pkgs[k]
                    if (p in desc)
                        printf "%-4s %-12s %-4s  # %s\n", s, p, tag[p], desc[p]
                    else
                        printf "%-4s %-12s %s\n", s, p, tag[p]
                }
            }
        }
    ' </dev/null >"$outfile"
    printf 'Wrote %s\n' "$outfile"
}

# Top-level retro command handler for generating default.tag from install media.
retro_tagfile() {
    retro_extract
    pushd "$EXTRACTDIR" >/dev/null || return
    slackware_extract_tagfiles "$TAGFILEDIR"
    slackware_generate_default_tag "$TAGFILEDIR" "$CONFDIR/default.tag"
    popd >/dev/null || return
}
