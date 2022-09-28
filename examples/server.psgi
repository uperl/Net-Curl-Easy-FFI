use warnings;
use 5.020;
use experimental qw( signatures );

package Plack::App::HelloWorld {

  use parent qw( Plack::Component );

  sub call ($self, $env) {
    my $path = $env->{PATH_INFO} || '/';
    return $self->return_404 if $path =~ /\0/;

    if($path eq '/hello-world') {
      return [200, ['Content-Type' => 'text/plain'], ["Hello World!\n"]];
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
