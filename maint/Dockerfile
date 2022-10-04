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
    screen                                           \
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
    Test2::Tools::MemoryCycle                        \
    https://dist.wdlabs.com/App-castyml-0.01.tar.gz  \
    Template                                         \
    FFI::Platypus                                    \
    FFI::C                                           \
    Plack::Component                                 \
    File::chdir                                      \
    Test2::V0                                        \
    Test::Script                                     \
    Devel::Cycle                                     \
    Pod::Abstract                                    \
    Net::Server::Fork                                \
    Const::Introspect::C                             \
 && rm -rf ~/.cpanm

ENV TEST_EXAMPLES 1
ENV LIVE_TESTS 1
