use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'https://localhost:5001/hello-world')
     ->setopt(followlocation => 1)
     ->setopt(ssl_verifypeer => 1)
     ->setopt(cainfo => 'examples/tls/Swirl-CA.crt')
     ->setopt(verbose => 1)
     ->perform;

