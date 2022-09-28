use Test2::V0 -no_srand => 1;
use 5.020;
use Test::Script qw( script_compiles script_runs );
use Path::Tiny qw( path );
use IO::Socket::INET;

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
    system 'screen -S net-swirl-curl-easy-test -d -m plackup examples/server.psgi';
  }
}
else
{
  diag '';
  diag '';
  diag '';
  diag 'only testing that scripts compile!';
  diag '';
  diag '';
}

my $path = path(__FILE__)->parent->parent->child('examples');

foreach my $script ($path->children)
{
  next unless $script->basename =~ /\.(pl|psgi)$/;
  subtest "$script" => sub {

    skip_all 'example script requires plack' if $script->basename =~ /\.psgi$/ && !$ENV{TEST_EXAMPLES};

    script_compiles "$script";
    if($ENV{TEST_EXAMPLES})
    {
      script_runs     "$script", { stdout => \my $out, stderr => \my $err };
      note "[out]\n$out" if $out ne '';
      note "[err]\n$err" if $err ne '';
    }
  };
}

done_testing;

