# Help Us Help You

When you have problems with `/usr/bin/ece`, `/usr/sbin/ece-install` or
any of the other commands on this repository, please provide us with a
couple of things so that we can help you in the best way possible:

## 1 — The versions of ece and ece-install

```
$ grep ^ece_scripts_version= /usr/{sbin/ece-install,bin/ece}
```

## 2 — The version of your operating system

Just run these three commands and give us the output:
```
$ lsb_release -a
$ cat /etc/debian_version
$ cat /etc/redhat-release
```

## 3 — For ece-install problems
3.1) Your `ece-install.conf` or `ece-install.yaml` file.

3.2) The contents of your sources.list (if you're on Debian/Ubuntu):
```
$ grep -r escenic /etc/apt/sources.list*
```

3.3) The log files of both `ece-install` and the instances you're setting up
(here, `engine1` is the instance):

```
/var/log/escenic/ece-install.log

/var/log/escenic/engine1.out
/var/log/escenic/engine1-catalina.out
/var/log/escenic/engine1-tomcat
/var/log/escenic/engine1-messages
```

## 4 - For `/usr/bin/ece` or `/etc/init.d/ece` problems
4.1 — The configuration files for your ece command
```
/etc/default/ece
/ece/escenic/ece.conf
/etc/escenic/ece-engine1.conf
```

4.2 The log files of the instance you're working with (`engine1` is the
default):

```
/var/log/escenic/engine1.out
/var/log/escenic/engine1-catalina.out
/var/log/escenic/engine1-tomcat
/var/log/escenic/engine1-messages
```

## I don't want to think!

> "I just want to copy and paste a bunch of commands and send them to
> you"

```
# Versions
grep ^ece_scripts_version= /usr/{sbin/ece-install,bin/ece}
lsb_release -a
cat /etc/debian_version
cat /etc/redhat-release

# Sources list(s):
grep -r escenic /etc/apt/sources.list*

# Conf and log files:
tar czf /tmp/$(date --iso)-debug-files.tar.gz \
  /var/log/escenic/ece-install.log \
  /var/log/escenic/engine1.out \
  /var/log/escenic/engine1-catalina.out \
  /var/log/escenic/engine1-tomcat \
  /var/log/escenic/engine1-messages \
  /etc/default/ece \
  /ece/escenic/ece.conf \
  /etc/escenic/ece-engine1.conf \
  /root/*.conf \
  /root/*.yaml
  
echo "Now, send this archive to us:" /tmp/$(date --iso)-debug-files.tar.gz

```
