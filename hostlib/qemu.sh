# shellcheck shell=bash
# QEMU preparation, execution, packaging, and workspace lifecycle.

# Runs QEMU while a QMP-driven install script controls it.
qemu_run_scripted_install() {
    local qemu_pid script_status qemu_status
    qemu_status=0

    echo "🏁 Starting QEMU for scripted install"
    "${QEMU_ARGS[@]}" &
    qemu_pid=$!
    # shellcheck disable=SC2034 # Read by sourced install script helpers.
    QEMU_PID=$qemu_pid

    if ! qmp_init; then
        log_error "Failed to initialize QMP for install script"
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
        return 1
    fi

    serial_start

    log_info "Running install script $QEMU_INSTALL_SCRIPT"
    (
        # shellcheck source=/dev/null
        source "$QEMU_INSTALL_SCRIPT"
    )
    script_status=$?
    if [[ $script_status -ne 0 ]]; then
        # Leave QEMU running on any install failure so the guest can be
        # inspected; the user exits QEMU manually when done investigating.
        if qmp_qemu_running; then
            log_error "Install script failed (status $script_status)."
            log_warn "QEMU has been left running so you can investigate the guest."
            log_warn "Close the QEMU window (or use the monitor) to exit."
        fi
        wait "$qemu_pid" 2>/dev/null || true
        return "$script_status"
    fi

    echo "🎉 Install script complete!"
    wait "$qemu_pid" || qemu_status=$?
    log_info "QEMU exited with status $qemu_status"
    return "$qemu_status"
}

# Removes an empty qemu.d directory left by failed preparation.
qemu_workspace_remove_if_empty() {
    # shellcheck disable=SC2153 # Set by retro before this library is sourced.
    if [[ -d $QEMU_D && -z $(ls -A "$QEMU_D") ]]; then
        log_debug "Removing empty QEMU directory $QEMU_D"
        rmdir "$QEMU_D"
    fi
}

# Extracts files, loads config, and assembles the QEMU command without launching
qemu_prepare() {
    log_debug "Preparing QEMU workspace"
    retro_extract
    mkdir -p "$QEMU_D"

    qemu_config_load

    pushd "$QEMU_D" >/dev/null || return 1

    qemu_media_select_for_command
    if ! qemu_disk_ensure_primary; then
        log_error "No bootable devices"
        popd >/dev/null || true
        qemu_workspace_remove_if_empty
        exit 1
    fi

    qemu_drives_build
    qemu_devices_build_globals
    qemu_chardevs_build_serials
    qemu_chardevs_build_parallels
    qemu_display_warn_if_unavailable

    qemu_command_build "$@"
    log_debug "QEMU preparation complete"

    echo
    qemu_endpoints_print
    echo
    qemu_devices_print
    echo
    echo "QEMU command: $QEMU_COMMAND"
    echo
    popd >/dev/null || true
}

# Runs QEMU directly and reports its exit status.
qemu_run_interactive() {
    local run_status=0

    echo "🏁 Starting QEMU"
    "${QEMU_ARGS[@]}" || run_status=$?
    log_info "QEMU exited with status $run_status"
    return "$run_status"
}

# Prepares and runs QEMU for either a boot or install command.
qemu_run() {
    local run_status=0

    log_debug "Preparing $COMMAND workflow"
    qemu_prepare "$@"

    pushd "$QEMU_D" >/dev/null || return
    if [[ $COMMAND == "install" && -n "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        qemu_run_scripted_install || run_status=$?
    else
        qemu_run_interactive || run_status=$?
    fi
    popd >/dev/null || return
    return "$run_status"
}

# Top-level retro command handler for booting a distro.
retro_boot() {
    qemu_run "$@"
}

# Top-level retro command handler for installing a distro.
retro_install() {
    qemu_run "$@"
}

# Packages prepared QEMU files with runnable host scripts.
retro_package() {
    local files tarname package_root package_dir item
    if [[ $# -ge 1 && $1 == "--hda" ]]; then
        log_info "Packaging launcher files plus hda.img"
        files=(hda.img retro.bat retro.sh)
        shift
    else
        log_info "Packaging full QEMU workspace"
        files=()
    fi
    # Prepare images and the rendered command only; never boot QEMU to package.
    qemu_prepare "$@"
    echo
    log_info "Packaging $CONFNAME..."
    {
        printf '@echo off\n'
        qemu_command_render_cmd
    } >"$QEMU_D/retro.bat"
    log_debug "Wrote $QEMU_D/retro.bat"
    {
        printf '#!/bin/sh\n'
        printf '%s\n' "$QEMU_COMMAND"
    } >"$QEMU_D/retro.sh"
    chmod +x "$QEMU_D/retro.sh"
    log_debug "Wrote $QEMU_D/retro.sh"
    tarname=$(printf '%s\n' "$CONFNAME" | tr / -)
    package_root=$TEMP_D/package
    package_dir=$package_root/$tarname
    rm -rf "$package_root"
    mkdir -p "$package_dir"
    if [[ ${#files[@]} -eq 0 ]]; then
        for item in "$QEMU_D"/*; do
            [[ -e "$item" ]] || continue
            cp -RL "$item" "$package_dir/"
        done
    else
        for item in "${files[@]}"; do
            [[ -e "$QEMU_D/$item" ]] || continue
            cp -RL "$QEMU_D/$item" "$package_dir/"
        done
    fi
    tar -C "$package_root" -czhf "$tarname.tar.gz" "$tarname"
    log_info "Package archive created: $tarname.tar.gz"
    ls -lh "$tarname.tar.gz"
}

# Top-level retro command handler for deleting extracted QEMU files.
retro_reset() {
    log_warn "Reset will remove QEMU images and extracted files for $CONFNAME"
    read -p "Really remove QEMU images and extracted files for $CONFNAME? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$EXTRACT_D"
        rm -rf "$QEMU_D"
        log_info "Distro reset."
    else
        log_warn "Reset aborted."
    fi
}
