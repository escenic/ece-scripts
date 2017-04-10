
# Version 3.x aka "akbash"

## /usr/sbin/ece-install

### ✔ Install ECE from APT 
Support for installing ECE & plugins using the escenic APT
repositories.

- ✔ Editor profile (Escenic Content Engine) 
- ✔ Presentation profile (Escenic Content Engine)
- ✔ Search profile (ECE's indexer-webapp + Solr)
- ✔ DB profile, ECE
- ✔ DB profile, ECE plugins
- ✔ Create publication(s) profile → Move to `/usr/bin/ece`
- ✔ Analysis profile (Escenic Analysis Engine)
- ✔ Analysis DB profile
- ✔ Cache server profile
- ✔ Assembly Tool

### ✔ Install ECE from RPMs
Support for installing ECE & plugins using the escenic RPM packages.

- ✔ Editor profile (Escenic Content Engine) 
- ✔ Presentation profile (Escenic Content Engine)
- ✔ Search profile (ECE's indexer-webapp + Solr)
- ✔ DB profile, ECE
- ✔ DB profile, ECE plugins
- ✔ Create publication(s) profile → Move to `/usr/bin/ece`
- ✔ Analysis profile (Escenic Analysis Engine)
- ✔ Analysis DB profile
- ✔ Cache server profile
- ✔ Assembly Tool

### ✔ Support for Varnish 4

Varnish 3 has reached its end of life and Varnish 4 is in the official
repositories of Debian stable, Ubuntu LTS and CentOS 7 and RedHat 7.

### ✔ YAML configuration file format

See the [unit tests](usr/local/src/unit-tests/ece-install-conf-file-reader-test.sh) for
configuration examples.

###  ✔ Remove the interactive mode. 

It's rarely used and complicates the source code and configuration
options unnecessarily.

## ✔ /usr/bin/ece

- ✔ New sub command: /usr/bin/ece create-publication

- ✔ Easy to extend, e.g. put `create-publication.sh` in a directory,
  e.g.`ece.d`, and get `ece create-publication`. The
  `create-publication` sub command is then included in TAB completion,
  help screens and `man` pages.


## Version 4.x
###  Easier to extend `ece-install`

Preferably in any language. Put a file in a directory and
`ece-install` will execute that file at a predictable point in time.

