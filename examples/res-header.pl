use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000/show-res-headers')
     ->setopt(headerfunction => sub ($, $data, $) {
       chomp $data;
       say "header: $data";
     })
     ->perform;

