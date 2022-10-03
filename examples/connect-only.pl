use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000')
     ->setopt(connect_only => 1)
     ->perform;

my $sock = $curl->getinfo('activesocket');
say $sock;


my $vec = '';
vec($vec, $sock, 1) = 1;
say $vec;

my $w = $vec;
select undef, $w, undef, 0;

my $req = qq{GET /hello-world HTTP/1.2\r\nHost: localhost\r\nUser-Agent: Foo/Bar\r\n\r\n};
say "sending:";
say $req;

my $bs = $curl->send(\$req);

say "sent $bs bytes (expected @{[ length $req ]})";


my $res;

while(1)
{
  my $r = $vec;
  select $r,  undef, undef, 0;

  next unless vec($r, $sock, 1);

  my $br = $curl->recv(\my $data, 4);

  next unless defined $br;

  last if $br == 0;
  say "br   =$br";
  say "data =$data";

  $res .= $data;
}

say $res;
