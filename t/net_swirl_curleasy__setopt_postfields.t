use Test2::V0 -no_srand => 1;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use lib 't/lib';
use Test2::Tools::MyTest;
use JSON::PP qw( decode_json encode_json );
use Test2::Tools::MemoryCycle;

skip_all 'set TEST_EXAMPLE=1 and install Plack to run this test' unless example_http;

foreach my $fieldname (qw( copypostfields postfields ))
{
  subtest $fieldname => sub {

    my $curl = Net::Swirl::CurlEasy->new;

    my @req = (encode_json({ foo => 'bar', baz => 1 }));
    my @raw;

    $curl->setopt(url            => "http://localhost:5000/post")
         ->setopt(post           => 1)
         ->setopt(httpheader     => ['Content-Type: application/json'])
         ->setopt(postfieldsize  => length($req[0]))
         ->setopt($fieldname     => shift @req)
         ->setopt(writefunction  => sub ($, $data, $) {
           push @raw, $data;
         })
         ->perform;

    is
      decode_json(join('', @raw)),
      { bar => 'foo', 1 => 'baz' };

    memory_cycle_ok $curl;

    try_ok { undef $curl } 'did not crash I guess?';

    keep_is_empty;
  };
}

keep_is_empty;

done_testing;
