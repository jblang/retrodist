echo '### Configuring mail...'

ETCPATH=/etc

if [ -x /usr/sbin/sendmail -o -L /usr/lib/sendmail -o -x /usr/lib/sendmail ]; then
    if [ ! -f "$ETCPATH/sendmail.cf" ]; then
        SENDMAILCF=

        for CANDIDATE in \
            /usr/src/sendmail/linux.smtp.cf \
            /usr/src/sendmail/cf/obj/tcpproto.cf \
            /usr/src/sendmail/linux.uucp.cf \
            /usr/src/sendmail/cf/obj/uucpproto.cf
        do
            if [ -f "$CANDIDATE" ]; then
                SENDMAILCF="$CANDIDATE"
                break
            fi
        done

        if [ -n "$SENDMAILCF" ]; then
            cp "$SENDMAILCF" "$ETCPATH/sendmail.cf"
            chmod 644 "$ETCPATH/sendmail.cf"
        fi
    fi
fi
