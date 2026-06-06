function hex_digit(c) {
  c = tolower(c)
  return index("0123456789abcdef", c) - 1
}

function hex_byte(h) {
  return hex_digit(substr(h, 1, 1)) * 16 + hex_digit(substr(h, 2, 1))
}

function screen_char(v) {
  if (v == 0 || v == 32) return " "
  if (v >= 32 && v <= 126) return sprintf("%c", v)
  return "."
}

{
  line = $0
  while (match(line, /0x[0-9a-fA-F][0-9a-fA-F]/)) {
    byte_count++
    if (byte_count % 2 == 1) {
      out = out screen_char(hex_byte(substr(line, RSTART + 2, 2)))
      char_count++
      if (char_count % cols == 0) {
        row_count++
        print out
        out = ""
      }
    }
    if (byte_count >= needed) exit
    line = substr(line, RSTART + RLENGTH)
  }
}

END {
  if (out != "") {
    row_count++
    print out
  }

  if (byte_count < needed) {
    printf "QMP xp returned only %d bytes; expected %d\n", byte_count, needed > "/dev/stderr"
    exit 1
  }
}
