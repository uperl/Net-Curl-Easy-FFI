use Test2::V0 -no_srand => 1;
use 5.020;
use Test2::Tools::Subtest qw( subtest_streamed );
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use lib 't/lib';
use Test2::Tools::MyTest;
use JSON::PP qw( decode_json encode_json );
use Test2::Tools::MemoryCycle;
use Data::Dumper qw( Dumper );

skip_all 'set TEST_EXAMPLE=1 and install Plack to run this test' unless example_http;

my %tests = (
  '1. basic'  => [
    21,
    '{"foo":"bar","baz":1}',
    ''
  ],
  '2. offset' => [
    21,
    ['xx{"foo":"bar","baz":1}', 2],
    ''
  ],
  '3. size' => [
    21,
    ['{"foo":"bar","baz":1}xx', undef, 21],
    ''
  ],
  '3. offset+size' => [
    21,
    ['xx{"foo":"bar","baz":1}xx', 2, 21],
    ''
  ],
  '3. too big' => [
    21,
    ['xx{"foo":"bar","baz":1}', 2, 200],
    ''
  ],
);

foreach my $test_name (sort keys %tests)
{

  subtest_streamed $test_name => sub {

    my $curl = Net::Swirl::CurlEasy->new;

    my($len, @req) = $tests{$test_name}->@*;
    my @raw;

    $curl->setopt(url           => "http://localhost:5000/post")
         ->setopt(post          => 1)
         ->setopt(httpheader    => ["Content-Type: application/json",
                                    "Content-Length: $len",
                                    "Expect:"])
         ->setopt(postfieldsize => $len)
         ->setopt(readfunction  => sub ($, $size, $) {
           my $chunk = shift @req;
           local $Data::Dumper::Terse  = 1;
           local $Data::Dumper::Indent = 2;
           note Dumper({ size => $size, chunk => $chunk });
           $chunk;
         })
         ->setopt(writefunction => sub ($, $data, $) {
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
