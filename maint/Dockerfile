ARG basetag=no-default

FROM plicease/ciperl:${basetag}
LABEL maintainer="Graham Ollis <plicease@cpan.org>"

RUN apt-get update                                   \
 && apt-get install --no-install-recommends          \
    curl                                             \
    pkg-config                                       \
    castxml                                          \
    man                                              \
    less                                             \
    libffi-dev                                       \
    expat                                            \
    libexpat1-dev                                    \
 && apt-get purge libcurl4-openssl-dev               \
 && apt-get -q autoremove                            \
 && apt-get -q clean                                 \
 && rm -rf /var/lib/apt/lists/*

ARG latest=no-default

RUN mkdir -p /tmp/build                              \
 && cd /tmp/build                                    \
 && curl -L https://curl.se/download/curl-${latest}.tar.gz | tar zxf - \
 && cd curl-${latest}                                \
 && ./configure                                      \
    --prefix=/opt/curl/${latest}                     \
    --with-openssl                                   \
 && make                                             \
 && make install                                     \
 && cd /                                             \
 && rm -rf /tmp/build

ARG debarch=no-default

RUN apt-get purge curl libcurl4                      \
 && cd /usr/bin                                      \
 && ln -s /opt/curl/${latest}/bin/* .                \
 && cd /usr/lib/${debarch}                           \
 && ln -s /opt/curl/${latest}/lib/lib* .             \
 && cd pkgconfig                                     \
 && ln -s /opt/curl/${latest}/lib/pkgconfig/* .      \
 && cd /usr/include/${debarch}                       \
 && ln -s /opt/curl/${latest}/include/* .

RUN cpanm -n                                         \
    https://dist.wdlabs.com/App-castyml-0.01.tar.gz  \
    Template                                         \
 && rm -rf ~/.cpanm

RUN cpanm -n                                         \
    FFI::Platypus                                    \
 && rm -rf ~/.cpanm
