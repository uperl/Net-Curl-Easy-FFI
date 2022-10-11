use Test2::V0 -no_srand => 1;
use Test2::Tools::Subtest qw( subtest_streamed );
use experimental qw( signatures );
use Test2::Require::Module 'Net::Server::Fork';
use Net::Swirl::CurlEasy;
use Test2::API qw( context );
use Data::Dumper qw( Dumper );
use Path::Tiny qw( path );
use lib 't/lib';
use Test2::Tools::MyTest;

skip_all 'Tests disabled unless LIVE_TESTS=1 and Net::Server::Fork is installed' unless echo;
echo_tls;

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
  alarm 10 unless $ENV{DISABLE_ALARM};

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

foreach my $type (qw( file blob )) {

  subtest_streamed "tls $type" => sub {
    skip_all 'test requires TLS/SSL' unless echo_tls;

    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm 10 unless $ENV{DISABLE_ALARM};

    my $curl = Net::Swirl::CurlEasy->new;

    if($type eq 'file')
    {
      $curl
         ->setopt( cainfo         => 'examples/tls/Swirl-CA.crt')
         ->setopt( sslcert        => 'examples/tls/client.crt')
         ->setopt( sslkey         => 'examples/tls/client.key')
    }
    else
    {
      local $@='';
      eval {
        $curl
           ->setopt( cainfo_blob    => path('examples/tls/Swirl-CA.crt')->slurp_raw)
           ->setopt( sslcert_blob   => path('examples/tls/client.crt')->slurp_raw)
           ->setopt( sslkey_blob    => path('examples/tls/client.key')->slurp_raw)
      };
      if(my $ex = $@)
      {
        if($ex->code == 48)
        {
          skip_all 'This CURL does not appear to have ssl blob options';
        }
        else
        {
          fail "settng blob options failed with: $ex";
          return;
        }
      }
    }

    $curl->setopt( url            => 'https://localhost:20204' )
         ->setopt( ssl_verifypeer => 1)
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

  }

};

keep_is_empty;

done_testing;
