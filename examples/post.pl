use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use JSON::PP qw( decode_json );
use Data::Dumper qw( Dumper );

my $curl = Net::Swirl::CurlEasy->new;

my $post_body = '{"foo":"bar","baz":1}';

my @res;

$curl->setopt(url => 'http://localhost:5000/post')
     ->setopt(post           => 1)
     ->setopt(httpheader     => ['Content-Type: application/json'])
     ->setopt(postfieldsize  => length($post_body))
     ->setopt(postfields     => $post_body)
     ->setopt(writefunction  => sub ($, $data, $) {
       push @res, $data;
     })
     ->perform;

my $res = decode_json(join('',@res));

$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

say Dumper($res);
