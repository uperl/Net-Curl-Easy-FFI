use Test2::V0 -no_srand => 1;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use lib 't/lib';
use Test2::Tools::MyTest;
use JSON::PP qw( decode_json );

skip_all 'set TEST_EXAMPLE=1 and install Plack to run this test' unless example_http;

subtest 'basic' => sub {

  my $curl = Net::Swirl::CurlEasy->new;

  my @raw;

  $curl->setopt(url => 'http://localhost:5000/show-req-headers')
       ->setopt(httpheader => ["Foo: bar", "Frooble: bits"])
       ->setopt(writefunction => sub ($, $data, $) {
         push @raw, $data;
       })
       ->perform;

  is
    decode_json(join('', @raw)),
    hash {
      field foo     => 'bar';
      field frooble => 'bits';
      etc;
    },
    'saw oo and Frooble in response with the correct values';
};

done_testing;
