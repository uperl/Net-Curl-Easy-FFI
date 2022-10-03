use warnings;
use 5.020;
use experimental qw( signatures );

package EchoServer {

  use parent qw( Net::Server::Fork );

  sub process_request ($self, $client=undef)
  {
    while(my $line = <STDIN>)
    {
      $line =~ s/[\015\012]+$//;
      last if $line eq '';
      print "$line\015\012";
    }
  }

}

EchoServer->run( host => '127.0.0.1' );
