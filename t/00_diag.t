use Test2::V0 -no_srand => 1;
use Config;

eval { require 'Test/More.pm' };

# This .t file is generated.
# make changes instead to dist.ini

my %modules;
my $post_diag;

$modules{$_} = $_ for qw(
  Alien::curl
  ExtUtils::MakeMaker
  FFI::C
  FFI::CheckLib
  FFI::Platypus
  FFI::Platypus::Buffer
  Path::Tiny
  Ref::Util
  Test2::API
  Test2::Require::Module
  Test2::Tools::MemoryCycle
  Test2::Tools::Subtest
  Test2::V0
  Test::Script
  URI::file
);

$post_diag = sub {
  local $@='';
  my $lib = eval {
    require './lib/Net/Swirl/CurlEasy/FFI.pm';
    Net::Swirl::CurlEasy::FFI->lib;
  };
  warn $@ if $@;
  diag "libcurl = @{[ $lib // 'undef' ]}";
  $@ = '';
  my $version = eval {
    require FFI::Platypus;
    FFI::Platypus->VERSION("2.00");
    my $ffi = FFI::Platypus->new( api => 2, lib => [$lib] );
    $ffi->function('curl_version' => [] => 'string')->call;
  };
  warn $@ if $@;
  if(defined $version) {
    diag "version = $_" for split /\s+/, $version;
  }
  unless($ENV{TEST_EXAMPLES}) {
    diag '';
    diag '';
    diag 'NOT TESTING EXAMPLES.';
    diag '(you can test examples by setting env TEST_EXAMPLES=1)';
    diag '(screen, Plack and other deps may be required)';
  }
};

my @modules = sort keys %modules;

sub spacer ()
{
  diag '';
  diag '';
  diag '';
}

pass 'okay';

my $max = 1;
$max = $_ > $max ? $_ : $max for map { length $_ } @modules;
our $format = "%-${max}s %s";

spacer;

my @keys = sort grep /(MOJO|PERL|\A(LC|HARNESS)_|\A(SHELL|LANG)\Z)/i, keys %ENV;

if(@keys > 0)
{
  diag "$_=$ENV{$_}" for @keys;

  if($ENV{PERL5LIB})
  {
    spacer;
    diag "PERL5LIB path";
    diag $_ for split $Config{path_sep}, $ENV{PERL5LIB};

  }
  elsif($ENV{PERLLIB})
  {
    spacer;
    diag "PERLLIB path";
    diag $_ for split $Config{path_sep}, $ENV{PERLLIB};
  }

  spacer;
}

diag sprintf $format, 'perl', "$] $^O $Config{archname}";

foreach my $module (sort @modules)
{
  my $pm = "$module.pm";
  $pm =~ s{::}{/}g;
  if(eval { require $pm; 1 })
  {
    my $ver = eval { $module->VERSION };
    $ver = 'undef' unless defined $ver;
    diag sprintf $format, $module, $ver;
  }
  else
  {
    diag sprintf $format, $module, '-';
  }
}

if($post_diag)
{
  spacer;
  $post_diag->();
}

spacer;

done_testing;

