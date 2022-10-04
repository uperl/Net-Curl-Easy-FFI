use Test2::V0 -no_srand => 1;
use 5.020;
use Test::Script qw( script_compiles script_runs );
use Path::Tiny qw( path );
use IO::Socket::INET;
use File::Which qw( which );

my $test_tls = 0;

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

  $sock = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => 5001,
    Proto    => 'tcp',
  );

  if($sock)
  {
    $sock->close;
    note 'Something is listening to port 5001, assuming it is nginx https proxy';
    $test_tls = 1;
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
      $test_tls = 1;
    }
    else
    {
      note 'could not find nginx, will skip TLS/SSL tests';
    }

  }
}

my $path = path(__FILE__)->parent->parent->child('examples');

foreach my $script ($path->children)
{
  next unless $script->basename =~ /\.(pl|psgi)$/;
  subtest "$script" => sub {

    skip_all 'example script requires plack' if $script->basename =~ /\.psgi$/ && !$ENV{TEST_EXAMPLES};

    script_compiles "$script";

    if($script->basename =~ /ssl\.pl$/ && !$test_tls)
    {
      note "example script requires TLS/SSL";
      return;
    }

    if($ENV{TEST_EXAMPLES})
    {
      script_runs     "$script", { stdout => \my $out, stderr => \my $err };
      note "[out]\n$out" if $out ne '';
      note "[err]\n$err" if $err ne '';
    }
  };
}

done_testing;

