use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use Data::Dumper qw( Dumper );
use JSON::PP qw( decode_json );

my $curl = Net::Swirl::CurlEasy->new;

my @raw;

$curl->setopt(url => 'http://localhost:5000/show-req-headers')
     ->setopt(httpheader => ["Shoesize: 10", "Accept:"])
     ->setopt(writefunction => sub ($, $data, $) {
       push @raw, $data;
     })
     ->perform;

my $data = decode_json(join('', @raw));

$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

say Dumper($data);
