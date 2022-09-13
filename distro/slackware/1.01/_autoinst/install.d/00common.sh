# outputs fdisk commands to add a partition
new_partition() {
cat <<EOF
n
$PARTMODE
EOF
# logical partition doesn't ask for a partition number
if [ "$PARTMODE" != "l" ]; then
    echo $PARTNUM
fi
cat <<EOF
$PARTBEGIN
$PARTEND
t
$PARTNUM
$PARTTYPE
EOF
}

# adds an extra newline to stdin so read loop works correctly
cat_newline() {
    cat
    echo
}

# converts a partition table to fdisk commands
fdisk_commands() {
    cat_newline | while read PARTMODE PARTNUM PARTBEGIN PARTEND PARTTYPE PARTIGNORE; do
        case $PARTMODE in
            [pel] ) new_partition ;;    # primary / extended / logical
            * ) ;;                      # ignore invalid partition modes
        esac        
    done
    echo "w"    # write partition
    echo        # extra newline
}

# runs fdisk with the partition table specified on stdin with the
# line format:
#   mode    num     begin   end     type
# mode: p = primary; e = extended; l = logical
# partnum: partition number: 1-4 (primary/extended); 5+: logical
# begin/end: in "cylinders" (depends on disk size and kernel version)
# type: 82 = swap, 83 = ext2
partition() {
    echo "### partitioning $1..."
    fdisk_commands | fdisk $1 > /dev/null
    if [ ! $? ]; then
        echo "# error partitioning $1! (o.O)"
        exit 1
    fi
    fdisk -l
}
