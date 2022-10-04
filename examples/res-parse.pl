use warnings;
use 5.020;
use experimental qw( signatures );
use HTTP::Response;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my @raw;

$curl->setopt(url => 'http://localhost:5000/show-res-headers')
     ->setopt(headerdata => 1)
     ->setopt(writefunction => sub ($, $chunk, $) {
       push @raw, $chunk
     })
     ->perform;

my $res = HTTP::Response->parse(join('', @raw));

say 'The Foo Header Was: ', $res->header('foo');
say 'The Content Was:    ', $res->decoded_content;
