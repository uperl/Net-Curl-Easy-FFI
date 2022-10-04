use Test2::V0 -no_srand => 1;
use Test2::Tools::Subtest qw( subtest_streamed );
use experimental qw( signatures );
use Test2::Require::Module 'Net::Server::Fork';
use Net::Swirl::CurlEasy;
use Test2::API qw( context );
use File::Which qw( which );
use Data::Dumper qw( Dumper );
use Env qw( @PATH );
use lib 't/lib';
use Test2::Tools::MyTest;

my $test_tls = 0;

if($ENV{LIVE_TESTS})
{
  my $sock = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => 20203,
    Proto    => 'tcp',
  );
  if($sock)
  {
    $sock->close;
    note 'Something is listening to port 20203, assuming it is corpus/echo-server.pl';
  }
  else
  {
    note 'starting corpus/echo-server.pl in a screen';
    system "screen -S net-swirl-curl-easy-test-echo -d -m $^X corpus/echo-server.pl";
    sleep 2;
  }

  $sock = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => 20204,
    Proto    => 'tcp',
  );
  if($sock)
  {
    $sock->close;
    note 'Something is listening to port 20204, assuming it is ghostunnel SSL proxy';
    $test_tls = 1;
  }
  else
  {
    my $gt = which('ghostunnel');
    $DB::single = 1;
    unless(defined $gt)
    {
      eval {
        require Alien::ghostunnel;
        unshift @PATH, Alien::ghostunnel->bin_dir;
      };
      $gt = which('ghostunnel');
    }
    if($gt)
    {
      note "starting ghostunnel SSL proxy in a screen ($gt)";
      system "screen -S net-swirl-curl-easy-test-echo-tls -d -m $gt server --allow-cn client --listen localhost:20204 --target localhost:20203 --cert examples/tls/localhost.crt --key examples/tls/localhost.key --cacert examples/tls/Swirl-CA.crt";
      sleep 2;
      $test_tls = 1;
    }
    else
    {
      note 'could not find ghostunnel, will skip TLS/SSL tests';
    }
  }
}
else
{
  skip_all 'Tests disabled unless LIVE_TESTS=1';
}

sub wait_on_socket ($sock, $type) {
  my $vec = '';
  vec($vec, $sock, 1) = 1;
  if($type eq 'write')
  {
    select $vec, undef, undef, 60000;
  }
  elsif($type eq 'read')
  {
    select undef, $vec, undef, 60000;
  }
  else
  {
    die 'huh?';
  }
}

sub msg_ok ($curl, $sock, $msg, %opt) {

  my $so_far = 0;

  $msg .= "\015\012";

  while(1)
  {
    my $bs = $curl->send(\$msg, $so_far);

    unless(defined $bs)
    {
      wait_on_socket $sock, 'write';
      next;
    }

    $so_far += $bs;

    last if $so_far == length $msg;
  }

  my $res;

  my $br_zero = 0;

  while(1)
  {
    my $br;

    my $buf;
    if($opt{'buf-allocate'})
    {
      $buf = "\0" x ($opt{'buf-size'} // 5);
      $br = $curl->recv(\$buf);
    }
    else
    {
      $br = $curl->recv(\$buf, $opt{'buf-size'} // 5);
    }

    unless(defined $br)
    {
      wait_on_socket $sock, 'read';
      next;
    }

    #note "br =$br";
    #note "buf=@{[ $buf // 'undef' ]}";

    $br_zero = 1 if $br == 0;

    $res .= $buf;

    last if length($res) == length($msg);

    #note "res=$res";
    #note "msg=$msg";

  }

  my $ctx = context;

  my $br = do {
    my $buf = "\0" x 10;
    $curl->recv(\$buf);
  };

  is $br, U(), "@{[ $opt{name} // '' ]} no bytes ready to read";
  is $br_zero, 0, "@{[ $opt{name} // '' ]} recv did not return 0";
  is $res, $msg, "@{[ $opt{name} // '' ]} message sent matches message received";

  $ctx->release;

}

subtest_streamed 'basic' => sub {

  local $SIG{ALRM} = sub { die "alarm\n" };
  alarm 10;

  my $curl = Net::Swirl::CurlEasy->new;

  $curl->setopt( url => 'http://localhost:20203' )
       ->setopt( connect_only => 1 )
       ->perform;

  my $sock = $curl->getinfo('activesocket');

  msg_ok $curl, $sock, "hello world", name => 'auto-allocate';
  msg_ok $curl, $sock, "hello world", name => 'pre-allocate';

  my $msg = "0123456789" x 100;
  $msg =~ s/..$//;
  is length($msg), 998, 'message will be exactly 500 bytes';

  msg_ok $curl, $sock, $msg, 'buf-size' => 100, 'name' => 'buf size divisible by message length';

  undef $curl;
  keep_is_empty;
};

subtest_streamed 'tls' => sub {
  skip_all 'test requires TLS/SSL' unless $test_tls;

  local $SIG{ALRM} = sub { die "alarm\n" };
  alarm 10;

  my $curl = Net::Swirl::CurlEasy->new;

  $curl->setopt( url            => 'https://localhost:20204' )
       ->setopt( ssl_verifypeer => 1)
       ->setopt( cainfo         => 'examples/tls/Swirl-CA.crt')
       ->setopt( sslcert        => 'examples/tls/client.crt')
       ->setopt( sslkey         => 'examples/tls/client.key')
       ->setopt( keypasswd      => 'password')
       ->setopt( connect_only   => 1 )
       ->setopt( certinfo       => 1 )
       ->perform;

  my $sock = $curl->getinfo('activesocket');

  is
    $curl->getinfo('certinfo'),
    array {
      item bag {
        item match qr/CN = localhost/;
        item match qr/CN = Snakeoil Swirl CA/;
        etc;
      };
      end;
    },
    '$curl->getinfo("certinfo")';
  note Dumper($curl->getinfo('certinfo'));
  note '$curl->getinfo("tls_session")->backend = ', $curl->getinfo('tls_session')->backend;
  note '$curl->getinfo("tls_ssl_ptr")->backend = ', $curl->getinfo('tls_ssl_ptr')->backend;

  msg_ok $curl, $sock, "hello world", name => 'auto-allocate';
  msg_ok $curl, $sock, "hello world", name => 'pre-allocate';

  my $msg = "0123456789" x 100;
  $msg =~ s/..$//;
  is length($msg), 998, 'message will be exactly 500 bytes';

  msg_ok $curl, $sock, $msg, 'buf-size' => 100, 'name' => 'buf size divisible by message length';

  undef $curl;
  keep_is_empty;

};

keep_is_empty;

done_testing;
