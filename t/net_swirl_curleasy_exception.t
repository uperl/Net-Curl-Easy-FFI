use Test2::V0 -no_srand => 1;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use URI::file;

subtest 'exception' => sub {
  my $curl = Net::Swirl::CurlEasy->new;

  my $url = URI::file->new_abs(__FILE__);
  $curl->setopt( url => "$url" );
  $curl->setopt( writefunction => sub {
    die 'oops';
  });

  my $expected_line;
  my @warn;
  eval {
    local $SIG{__WARN__} = sub ($msg) {
      if($msg =~ /oops/)
      {
        push @warn, $msg;
      }
      else
      {
        warn $msg;
      }
    };
    $expected_line = __LINE__; $curl->perform;
  };
  my $error = $@;

  is
    $error,
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception' ] => T();
      call filename  => __FILE__;
      call line      => $expected_line;
      call package   => 'main';
      call code      => 23;
      call strerror  => 'Failed writing received data to disk/application';
      call as_string => "Failed writing received data to disk/application at @{[ __FILE__ ]} line $expected_line.";
    },
    'throws exception on error';

  is
    \@warn,
    array {
      item match qr/^oops/;
      end;
    },
    'exactly the warnings we expect';

};

done_testing;
