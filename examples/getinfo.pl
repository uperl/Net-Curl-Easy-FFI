use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->perform;

say "The Content-Type is: ", $curl->getinfo('content_type');
