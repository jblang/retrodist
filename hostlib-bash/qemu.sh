# shellcheck shell=bash
# QEMU preparation, execution, packaging, and workspace lifecycle.

# Stops a just-started QEMU process after host transport initialization fails.
qemu_abort_startup() {
    local qemu_pid=$1 message=$2

    log_error "$message"
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
    serial_stop
}

# Runs QEMU while a QMP-driven install script controls it.
qemu_run_scripted_install() {
    local qemu_pid script_status qemu_status
    qemu_status=0

    echo "🏁 Starting QEMU for scripted install"
    "${QEMU_ARGS[@]}" 6>&- 7>&- &
    qemu_pid=$!
    # shellcheck disable=SC2034 # Read by sourced install script helpers.
    QEMU_PID=$qemu_pid

    if ! qmp_init; then
        qemu_abort_startup "$qemu_pid" "Failed to initialize QMP for install script"
        return 1
    fi

    if ! serial_start; then
        qemu_abort_startup "$qemu_pid" "Failed to initialize serial transport"
        return 1
    fi

    log_info "Running install script $QEMU_INSTALL_SCRIPT"
    (
        # shellcheck source=/dev/null
        source "$QEMU_INSTALL_SCRIPT"
    )
    script_status=$?
    if [[ $script_status -ne 0 ]]; then
        # Leave QEMU running on any install failure so the guest can be
        # inspected; the user exits QEMU manually when done investigating.
        if qmp_vm_is_running; then
            log_error "Install script failed (status $script_status)."
            log_warn "QEMU has been left running so you can investigate the guest."
            log_warn "Close the QEMU window (or use the monitor) to exit."
        fi
        wait "$qemu_pid" 2>/dev/null || true
        serial_stop
        return "$script_status"
    fi

    echo "🎉 Install script complete!"
    wait "$qemu_pid" || qemu_status=$?
    serial_stop
    log_info "QEMU exited with status $qemu_status"
    return "$qemu_status"
}

# Removes an empty qemu.d directory left by failed preparation.
qemu_remove_empty_workspace() {
    # shellcheck disable=SC2153 # Set by retro before this library is sourced.
    if [[ -d $QEMU_D && -z $(ls -A "$QEMU_D") ]]; then
        log_debug "Removing empty QEMU directory $QEMU_D"
        rmdir "$QEMU_D"
    fi
}

# Extracts files, loads config, and assembles the QEMU command without launching
qemu_prepare() {
    log_debug "Preparing QEMU workspace"
    retro_extract || return 1
    mkdir -p "$QEMU_D" || return 1

    config_load || return 1

    pushd "$QEMU_D" >/dev/null || return 1

    device_select_media
    if ! device_ensure_primary_disk; then
        log_error "No bootable devices"
        popd >/dev/null || true
        qemu_remove_empty_workspace
        exit 1
    fi

    if ! device_build_drives ||
        ! device_build_globals ||
        ! device_build_serials ||
        ! device_build_parallels ||
        ! device_build_qmp_pipe ||
        ! config_warn_if_display_unavailable ||
        ! command_build; then
        popd >/dev/null || true
        return 1
    fi
    log_debug "QEMU preparation complete"

    echo
    network_print_endpoints
    echo
    device_print
    echo
    echo "QEMU command: $QEMU_COMMAND"
    echo
    popd >/dev/null || true
}

# Runs QEMU directly and reports its exit status.
qemu_run_interactive() {
    local handshake_pid run_status=0

    qmp_negotiate_capabilities &
    handshake_pid=$!

    echo "🏁 Starting QEMU"
    "${QEMU_ARGS[@]}" 6>&- 7>&- || run_status=$?
    if kill -0 "$handshake_pid" 2>/dev/null; then
        kill "$handshake_pid" 2>/dev/null || true
    fi
    wait "$handshake_pid" 2>/dev/null || true
    log_info "QEMU exited with status $run_status"
    return "$run_status"
}

# Prepares and runs QEMU for either a boot or install command.
qemu_run() {
    local run_status=0

    log_debug "Preparing $COMMAND workflow"
    qemu_prepare || return 1

    pushd "$QEMU_D" >/dev/null || return
    qmp_set_defaults
    if [[ -n "${QEMU_QMP_PIPE:-}" && "$QEMU_QMP_PIPE" != "none" ]]; then
        qmp_check_prereqs || {
            popd >/dev/null || true
            return 1
        }
        qmp_pipe_open || {
            popd >/dev/null || true
            return 1
        }
        qmp_log_reset || {
            qmp_pipe_close
            popd >/dev/null || true
            return 1
        }
    fi
    if [[ $COMMAND == "install" && -n "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        qemu_run_scripted_install || run_status=$?
    else
        qemu_run_interactive || run_status=$?
    fi
    qmp_pipe_close
    popd >/dev/null || return
    return "$run_status"
}

# Top-level retro command handler for booting a distro.
retro_boot() {
    qemu_run
}

# Top-level retro command handler for installing a distro.
retro_install() {
    qemu_run
}

# Writes portable Windows and POSIX launchers into QEMU_D.
qemu_write_package_launchers() {
    local qmp_in qmp_out

    {
        printf '@echo off\n'
        command_render_cmd
    } >"$QEMU_D/retro.bat" || return 1
    log_debug "Wrote $QEMU_D/retro.bat"
    {
        printf '#!/bin/sh\n'
        if [[ -n "${QEMU_QMP_PIPE:-}" && "$QEMU_QMP_PIPE" != "none" ]]; then
            qmp_in=$(command_quote_posix_word "$QEMU_QMP_PIPE.in")
            qmp_out=$(command_quote_posix_word "$QEMU_QMP_PIPE.out")
            printf 'if test ! -p %s || test ! -p %s; then\n' "$qmp_in" "$qmp_out"
            printf '  rm -f %s %s\n' "$qmp_in" "$qmp_out"
            printf '  mkfifo %s %s\n' "$qmp_in" "$qmp_out"
            printf 'fi\nexec 6<>%s\nexec 7<>%s\n' "$qmp_in" "$qmp_out"
            printf '%s 6>&- 7>&-\n' "$QEMU_COMMAND"
        else
            printf '%s\n' "$QEMU_COMMAND"
        fi
    } >"$QEMU_D/retro.sh" || return 1
    chmod +x "$QEMU_D/retro.sh" || return 1
    log_debug "Wrote $QEMU_D/retro.sh"
}

# Copies all prepared files into a package.
qemu_copy_package_files() {
    local package_dir=$1 item

    mkdir -p "$package_dir" || return 1
    for item in "$QEMU_D"/*; do
        [[ -e "$item" ]] || continue
        cp -RL "$item" "$package_dir/" || return 1
    done
}

# Creates and reports the final compressed package archive.
qemu_create_package_archive() {
    local package_root=$1 tarname=$2

    tar -C "$package_root" -czhf "$tarname.tar.gz" "$tarname" || return 1
    log_info "Package archive created: $tarname.tar.gz"
    ls -lh "$tarname.tar.gz"
}

# Packages prepared QEMU files with runnable host scripts.
retro_package() {
    local tarname package_root package_dir
    log_info "Packaging full QEMU workspace"
    # Prepare images and the rendered command only; never boot QEMU to package.
    qemu_prepare || return 1
    echo
    log_info "Packaging $CONFNAME..."
    qemu_write_package_launchers || return 1
    tarname=$(printf '%s\n' "$CONFNAME" | tr / -)
    package_root=$TEMP_D/package
    package_dir=$package_root/$tarname
    rm -rf "$package_root"
    qemu_copy_package_files "$package_dir" || return 1
    qemu_create_package_archive "$package_root" "$tarname"
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
