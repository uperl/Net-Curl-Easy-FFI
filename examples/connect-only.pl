use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000')
     ->setopt(connect_only => 1)
     ->perform;

my $sock = $curl->getinfo('activesocket');
say $sock;
