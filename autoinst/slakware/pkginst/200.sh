SLACK_ADM_DIR=var/adm
SLACK_SPOOL_DIR=var/spool
SLACK_TIMECONFIG=$SLACK_ADM_DIR/setup/setup.timeconfig
SLACK_LILOCONFIG=$SLACK_ADM_DIR/setup/setup.liloconfig
SLACK_PKGTOOL_SOURCE=/bin/pkgtool.tty
SLACK_SETUP_SOURCE=/bin/setup.tty

. "$SOURCEMOUNT/autoinst.d/slakware/pkginst/shared.sh"
