# shellcheck shell=sh
_mail_config() {
    log_div
    log_info "Configuring mail..."

    if [ -x /usr/sbin/sendmail -o -L /usr/lib/sendmail -o -x /usr/lib/sendmail ]; then
        log_info "Detected sendmail installation"
        if [ ! -f "$ETCPATH/sendmail.cf" ]; then
            SENDMAILCF=

            for CANDIDATE in \
                /usr/src/sendmail/linux.smtp.cf \
                /usr/src/sendmail/cf/obj/tcpproto.cf \
                /usr/src/sendmail/linux.uucp.cf \
                /usr/src/sendmail/cf/obj/uucpproto.cf; do
                log_debug "Checking sendmail template: $CANDIDATE"
                if [ -f "$CANDIDATE" ]; then
                    SENDMAILCF="$CANDIDATE"
                    log_info "Selected sendmail template: $SENDMAILCF"
                    break
                fi
            done

            if [ -n "$SENDMAILCF" ]; then
                log_info "Creating file: $ETCPATH/sendmail.cf"
                cp "$SENDMAILCF" "$ETCPATH/sendmail.cf"
                chmod 644 "$ETCPATH/sendmail.cf"
            else
                log_warn "No sendmail.cf template found; leaving mail unconfigured"
            fi
        else
            log_info "$ETCPATH/sendmail.cf already exists; leaving it unchanged"
        fi
    else
        log_info "No sendmail installation detected; skipping mail configuration"
    fi
}
