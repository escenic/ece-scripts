Docker environment for testing things
-------------------------------------

ece-scripts contain some potentially destructive commands, and it is
sometimes wise to perform some tests in a controlled environment.

The docker environment provided in this directory is aimed at
developers who need a "test bed" for making changes to the ece-scripts
itself.

From this directory you can run 'docker-compose build' to get a build
which contains 'escenic-common-scripts' installed from source.

The set of packages to "install" (essentially `cp -rp`'ed to the
image) can be provided using the "PACKAGES" environment variable.
There are a few "sets" of packages that are provided in `all/.env` and
`installer/.env`.  To use these, change to the `all` or `installer`
directory and run `docker-compose build` to build the image.

To drop into a shell to play around with a command, run this command,
from this directory (or from one of the directories with an
appropriate `.env` file.

``` shell
docker-compose run --rm ece-scripts bash
```


Summary
-------

``` shell
cd engine
docker-compose build
docker-compose run --rm ece-install bash
ece status
```
