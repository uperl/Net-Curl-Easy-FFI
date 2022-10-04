use Test2::V0 -no_srand => 1;
use 5.020;
use Test::Script qw( script_compiles script_runs );
use Path::Tiny qw( path );
use IO::Socket::INET;
use lib 't/lib';
use Test2::Tools::MyTest;

example_http;
example_https;

my $path = path(__FILE__)->parent->parent->child('examples');

foreach my $script ($path->children)
{
  next unless $script->basename =~ /\.(pl|psgi)$/;
  subtest "$script" => sub {

    skip_all 'example script requires plack' if $script->basename =~ /\.psgi$/ && !$ENV{TEST_EXAMPLES};

    script_compiles "$script";

    if($script->basename =~ /ssl\.pl$/ && !example_https)
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

