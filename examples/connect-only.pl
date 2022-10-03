use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

# 1. connectonly
$curl->setopt(url => 'http://localhost:5000')
     ->setopt(connect_only => 1)
     ->perform;

# 2. utility function
sub wait_on_socket ($sock, $for_recv=undef) {
  my $vec = '';
  vec($vec, $sock, 1) = 1;
  if($for_recv) {
    select $vec, undef, undef, 60000;
  } else {
    select undef, $vec, undef, 60000;
  }
}

# 3. activesocket
my $sock = $curl->getinfo('activesocket');

my $so_far = 0;
my $req = join "\015\012", 'GET /hello-world HTTP/1.2',
                           'Host: localhost',
                           'User-Agent: Foo/Bar',
                           '','';

while(1) {
  # 4. send
  my $bs = $curl->send(\$req, $so_far);

  unless(defined $bs) {
    wait_on_socket $sock;
    next;
  }

  $so_far += $bs;

  last if $so_far == length $req;
}

my $res;

while(1) {
  # 5. recv
  my $br = $curl->recv(\my $data, 4);

  unless(defined $br) {
    wait_on_socket $sock, 1;
    next;
  }

  last if $br == 0;

  $res .= $data;
}

say $res;
