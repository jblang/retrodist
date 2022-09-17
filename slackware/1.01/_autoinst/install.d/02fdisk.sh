echo "## creating partitions..."
# 500MB disk with 16MB of swap
# the rest is the ext2 / partition
partition /dev/hda <<EOF
# mode  num     begin   end     type
p       1       1       33      82  # 16MB swap
p       2       34      1015    83  # ext2
EOF