use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my $password = 'password';

$curl->setopt(url            => 'https://localhost:5001/hello-world')
     ->setopt(ssl_verifypeer => 1)
     ->setopt(cainfo         => 'examples/tls/Swirl-CA.crt')
     ->setopt(sslcerttype    => "p12")
     ->setopt(sslcert        => 'examples/tls/client.p12')
     ->setopt(keypasswd      => $password)
     ->setopt(verbose => 1)
     ->perform;

die "unable to make request" unless $curl->getinfo('response_code') == 200;
