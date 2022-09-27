# Reference libcurl docker image

This directory contains the Dockerfile and build/test scripts for the libcurl
reference build used to generate parts of Net::Swirl::CurlEasy.  It currently
only builds the latest (as practicable) version of curl, but an oldest and too
old version will probably be added as soon as we can figure out which versions
those should be.

If you are just modifying manually maintained bindings or adding tests then you
should not need to use the reference docker image (unless you want to test with one
of the reference builds; though this is porbably only necessary if CI fails with one
of these builds).  If you are replacing automatically generated bindings, or making
changes to the introspection code itself you will have to use the reference docker
image.

Here are the steps:

 * If you need to modify the reference docker image itself (adding prerequisites, or
   updating to a new version of Debian), run `./maint/ref-build` to build the new
   image locally.  (If you are also the `Net-Swirl-CurlEasy` maintainer you will
   want to run `./maint/ref-push` to push the image to dockerhub, once you are sure
   the image is correct).

 * Run the introspection and code generation script: `./maint/ref-update`.

 * If changes were made to `lib/Swirl/CurlEasy.pm` POD then you will then want
   to run `dzil build` to update the README.md in the project root.  (you can
   install `Dist::Zilla` by running `cpanm Dist::Zilla && dzil authordeps | cpanm && dzil listdeps | cpanm`).

 * It is advisable to run the test suite against the reference version(s) of
   `libcurl`, since CI will do that and your PR will not be merged unless CI
   passes.  To run the test suite against the old and new versions, run `./maint/ref-test`.

 * Submit your PR!

Some other useful tools:

 * `./maint/ref-config` contains configuration items, such as the old, new and unsupported
   versions of `libcurl` (we also build an unsupported version immediately prior to
   the old version to find symbols that we need to check for during install to make sure
   that `libcurl` is at least up to the old version; if you bump the old version,
   make sure you bump the unsupported version).  If you bump either the old or new version
   you will need to rebuild the reference docker image.

 * `./maint/ref-exec` will run a command in the reference docker image.

 * `./maint/ref-shell` will give you a shell inside the reference docker image.  This can
   be useful for debugging build or run problems.

 * `./maint/ref-symbols` will list the symbols in the unsupported, old and new versions of
   `libcurl`.

 * `castxml` and `castyml` run from inside the `ref-shell` will dump a C header file using
   `libclang`.  The latter will restore some of the hierarchy to the function argument
   types, which can be helpful in debugging the function introspection.  Example:
   `castyml /usr/include/x86_64-linux-gnu/curl/curl.h`.
