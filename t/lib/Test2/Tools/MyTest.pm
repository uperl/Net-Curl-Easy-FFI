use warnings;
use 5.020;
use experimental qw( signatures );

package Test2::Tools::MyTest {

  use Exporter qw( import );
  use Test2::Tools::Compare ();
  use Test2::API qw( context );
  use IO::Socket::INET;
  use Test2::Tools::Basic qw( note );
  use File::Which qw( which );
  use Env qw( @PATH );

  our @EXPORT = qw( keep_is_empty example_http example_https echo echo_tls );

  sub keep_is_empty ($name=undef) {
    $name = "%keep is empty";

    Test2::Tools::Compare::is \%Net::Swirl::CurlEasy::keep, {}, $name;
  }

  sub example_http {
    state $answer;
    return $answer if defined $answer;

    if($ENV{TEST_EXAMPLES})
    {
      my $sock = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => 5000,
        Proto    => 'tcp',
      );
      if($sock)
      {
        $sock->close;
        note 'Something is listening to port 5000, assuming it is examples/server.psgi';
      }
      else
      {
        note 'starting examples.psgi in a screen';
        system 'screen -S net-swirl-curl-easy-test-http -d -m plackup examples/server.psgi';
        sleep 2;
      }
      return $answer = 1;
    }
    else
    {
      return $answer = 0;
    }
  }

  sub example_https {
    state $answer;
    return $answer if defined $answer;

    return $answer = 0 unless example_http;

    my $sock = IO::Socket::INET->new(
      PeerAddr => 'localhost',
      PeerPort => 5001,
      Proto    => 'tcp',
    );

    if($sock)
    {
      $sock->close;
      note 'Something is listening to port 5001, assuming it is nginx https proxy';
      return $answer = 1;
    }
    else
    {
      my $nginx = which('nginx');

      # Try the default location on macOS+MacPorts and Linux
      foreach my $try (qw( /opt/local/sbin/nginx /usr/sbin/nginx ))
      {
        last if $nginx;
        $nginx = $try if -x $try;
      }

      if($nginx)
      {
        note 'starting nginx https proxy in a screen';
        system "screen -S net-swirl-curl-easy-test-https -d -m $nginx -p examples/tls -c nginx.conf";
        sleep 2;
        return $answer = 1;
      }
      else
      {
        note 'could not find nginx, will skip TLS/SSL tests';
        return $answer = 0;
      }
    }
  }

  sub echo {
    state $answer;
    return $answer if defined $answer;

    if($ENV{LIVE_TESTS})
    {
      my $sock = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => 20203,
        Proto    => 'tcp',
      );
      if($sock)
      {
        $sock->close;
        note 'Something is listening to port 20203, assuming it is corpus/echo-server.pl';
        return $answer = 1;
      }
      else
      {
        note 'starting corpus/echo-server.pl in a screen';
        system "screen -S net-swirl-curl-easy-test-echo -d -m $^X corpus/echo-server.pl";
        sleep 2;
        return $answer = 1;
      }
    }
    else
    {
      return $answer = 0;
    }
  }

  sub echo_tls {
    state $answer;
    return $answer if defined $answer;

    return $answer = 0 unless echo;

    my $sock = IO::Socket::INET->new(
      PeerAddr => 'localhost',
      PeerPort => 20204,
      Proto    => 'tcp',
    );
    if($sock)
    {
      $sock->close;
      note 'Something is listening to port 20204, assuming it is ghostunnel SSL proxy';
      return $answer = 1;
    }
    else
    {
      my $gt = which('ghostunnel');
      unless(defined $gt)
      {
        eval {
          require Alien::ghostunnel;
          unshift @PATH, Alien::ghostunnel->bin_dir;
        };
        $gt = which('ghostunnel');
      }
      if($gt)
      {
        note "starting ghostunnel SSL proxy in a screen ($gt)";
        system "screen -S net-swirl-curl-easy-test-echo-tls -d -m $gt server --allow-cn client --listen localhost:20204 --target localhost:20203 --cert examples/tls/localhost.crt --key examples/tls/localhost.key --cacert examples/tls/Swirl-CA.crt";
        sleep 2;
        return $answer = 1;
      }
      else
      {
        note 'could not find ghostunnel, will skip TLS/SSL tests';
        return $answer = 0;
      }
    }
  }

}

1;
