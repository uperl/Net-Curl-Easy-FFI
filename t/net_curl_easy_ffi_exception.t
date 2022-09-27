use Test2::V0 -no_srand => 1;
use Net::Curl::Easy::FFI;
use URI::file;

subtest 'exception' => sub {
  my $curl = Net::Curl::Easy::FFI->new;

  my $url = URI::file->new_abs(__FILE__);
  $curl->setopt( url => "$url" );
  $curl->setopt( writefunction => sub {
    die 'oops';
  });

  my $expected_line;
  eval {
    $expected_line = __LINE__; $curl->perform;
  };
  my $error = $@;

  is
    $error,
    object {
      call [ isa => 'Net::Curl::Easy::FFI::Exception' ] => T();
      call filename  => __FILE__;
      call line      => $expected_line;
      call package   => 'main';
      call code      => 23;
      call strerror  => 'Failed writing received data to disk/application';
      call as_string => "Failed writing received data to disk/application at @{[ __FILE__ ]} line $expected_line.";
    },
    'throws exception on error';

};

done_testing;
