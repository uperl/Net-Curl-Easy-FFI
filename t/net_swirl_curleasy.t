use Test2::V0 -no_srand => 1;
use 5.020;
use experimental qw( postderef signatures );
use Net::Swirl::CurlEasy;
use URI::file;
use Path::Tiny qw( path );
use lib 't/lib';
use Test2::Tools::MemoryCycle;

subtest 'very basic' => sub {
  my $curl = Net::Swirl::CurlEasy->new;
  isa_ok $curl, 'Net::Swirl::CurlEasy';

  my $url = URI::file->new_abs('corpus/data.txt');
  try_ok { $curl->setopt( url => "$url" ) } "\$curl->setopt( url => '$url' )";

  my $content;

  try_ok {
    $curl->setopt( writefunction => sub ($, $data, $) {
      $content .= $data;
    });
  } "\$curl->setopt( writefunction => sub { ... } )";

  try_ok { $curl->perform } "\$curl->perform";

  is
    $curl,
    object {
      call [ isa => 'Net::Swirl::CurlEasy' ] => T();
      call [ getinfo => 'scheme' ] => 'FILE';
    },
    'final object state';

  is $content, path('corpus/data.txt')->slurp_raw, 'content matches';

  note "ssl_engines:$_" for $curl->getinfo('ssl_engines')->@*;

  memory_cycle_ok $curl;

  try_ok { undef $curl } 'did not crash I guess?';
};

subtest 'writedata' => sub {

  my $curl = Net::Swirl::CurlEasy->new;

  my $url = URI::file->new_abs('corpus/data.txt');
  try_ok { $curl->setopt( url => "$url" ) } "\$curl->setopt( url => '$url' )";

  my $content;

  try_ok {
    open my $fh, ">", \$content;
    $curl->setopt( writedata => $fh );
  } "\$curl->setopt( writedata => \$fh )";

  try_ok { $curl->perform } "\$curl->perform";

  is $content, path('corpus/data.txt')->slurp_raw, 'content matches';

  memory_cycle_ok $curl;

  try_ok { undef $curl } 'did not crash I guess?';
};

subtest 'clone' => sub {

  my $curl1 = Net::Swirl::CurlEasy->new;

  my $content = '';
  open my $fh, '>', \$content;

  my $url = URI::file->new_abs('corpus/data.txt');
  $curl1->setopt( url           => "$url" );
  $curl1->setopt( writedata     => [$fh]  );
  $curl1->setopt( writefunction => sub ($, $data, $array) {
    my($fh) = @$array;
    print $fh $data;
  });

  my $curl2 = $curl1->clone;

  memory_cycle_ok $curl1, 'no memory cycles original';
  memory_cycle_ok $curl2, 'no memory cycles clone';

  try_ok { $curl2->perform } "\$curl2->perform";

  is $content, path('corpus/data.txt')->slurp_raw, 'content matches';

  memory_cycle_ok $curl1, 'no memory cycles original (still)';
  memory_cycle_ok $curl2, 'no memory cycles clone (still)';

};

subtest 'slist' => sub {

  is(
    Net::Swirl::CurlEasy::Slist->new(qw( foo bar baz )),
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Slist' ] => T();
      call ptr => T();
      call as_list => [ qw( foo bar baz ) ];
      call [ append => 'roger' ] => object { call [ isa => 'Net::Swirl::CurlEasy::Slist' ] => T() };
      call as_list => [ qw( foo bar baz roger ) ];
    },
    'slist with stuff in it'
  );

  is(
    Net::Swirl::CurlEasy::Slist->new(),
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Slist' ] => T();
      call ptr => U();
      call as_list => [];
      call [ append => 'roger' ] => object { call [ isa => 'Net::Swirl::CurlEasy::Slist' ] => T() };
      call ptr => T();
      call as_list => [ 'roger' ];
    },
    'start with empty',
  );

  memory_cycle_ok( Net::Swirl::CurlEasy::Slist->new(qw( foo bar baz )) );
};

done_testing;
