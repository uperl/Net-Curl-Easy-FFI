use Test2::V0 -no_srand => 1;
use Net::Swirl::CurlEasy;
use URI::file;
use Path::Tiny qw( path );

subtest 'very basic' => sub {
  my $curl = Net::Swirl::CurlEasy->new;
  isa_ok $curl, 'Net::Swirl::CurlEasy';

  my $url = URI::file->new_abs(__FILE__);
  try_ok { $curl->setopt( url => "$url" ) } "\$curl->setopt( url => '$url' )";

  my $content;

  try_ok {
    $curl->setopt( writefunction => sub {
      $content .= $_[0];
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

  is $content, path(__FILE__)->slurp_raw, 'content matches';

  use YAML ();
  note YAML::Dump($curl->getinfo('ssl_engines'));

  try_ok { undef $curl } 'did not crash I guess?';
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

};

done_testing;
