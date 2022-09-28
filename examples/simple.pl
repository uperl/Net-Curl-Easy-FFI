use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000')
     ->setopt(followlocation => 1)  # equivalent to curl -L
     ->perform;

