# Debian

[Debian](https://www.debian.org/) was established in August 1993 by Ian Murdock, who published a [manifesto](https://www.debian.org/doc/manuals/project-history/manifesto.en.html) outlining the project's goals. Like Slackware, it was created out of frustration with the bugs in SLS.  More historical information is on [Wikipedia](https://en.wikipedia.org/wiki/Debian). 

## Releases

- [0.91 / Infomagic](./0.91/infomagic/README.md)
- [0.93R6 / official](./0.93R6/official/README.md)
- [1.1 / Buzz](./buzz/official/README.md)
- [1.2 / Rex](./rex/official/README.md)
- [1.3 / Bo](./bo/official/README.md)

## Automation Status

- `0.91`
  Working `autoinst` and `autoconf`.

- `0.93R6`
  Configured in the repo, but automatic install is currently blocked by missing MSDOS support in the installer kernel.

- `Buzz`
- `Rex`
- `Bo`
  Working `autoinst`. `autoconf` is not implemented yet.

For implementation details on the shared Debian installer scripts, see [autoinst/debian/README.md](/Users/jblang/repos/retrodist/autoinst/debian/README.md).
