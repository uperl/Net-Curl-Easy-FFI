use warnings;
use 5.020;
use experimental qw( signatures );

package Plack::App::HelloWorld {

  use JSON::PP qw( encode_json );
  use parent qw( Plack::Component );

  sub call ($self, $env) {
    my $path = $env->{PATH_INFO} || '/';
    return $self->return_404 if $path =~ /\0/;

    if($path eq '/hello-world') {
      return [200, ['Content-Type' => 'text/plain'], ["Hello World!\n"]];
    }

    if($path eq '/show-req-headers') {
      my %headers = map { lc($_ =~ s/^HTTP_//r) => $env->{$_}} grep /^HTTP_/, keys $env->%*;
      return [200, ['Content-Type' => 'application/json'], [encode_json(\%headers)]];
    }

    if($path eq '/show-res-headers') {
      return [200, ['Content-Type' => 'text/plain', Foo => 'Bar', Baz => 1], ["Check the headers\n"]];
    }

    if($path eq '/') {
      return [301, ['Location' => '/hello-world'], ['']];
    }

    return $self->return_404;
  }

  sub return_404 ($self) {
    return [404, ['Content-Type' => 'text/plain'], ['not found']];
  }
}

Plack::App::HelloWorld->new->to_app;
