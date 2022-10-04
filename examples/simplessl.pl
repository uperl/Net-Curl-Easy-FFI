use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url            => 'https://localhost:5001/hello-world')
     ->setopt(ssl_verifypeer => 1)
     ->setopt(cainfo         => 'examples/tls/Swirl-CA.crt')
     ->setopt(sslcert        => 'examples/tls/client.crt')
     ->setopt(sslkey         => 'examples/tls/client.key')
     ->setopt(keypasswd      => 'password')
     ->setopt(verbose => 1)
     ->perform;

die "unable to make request" unless $curl->getinfo('response_code') == 200;
