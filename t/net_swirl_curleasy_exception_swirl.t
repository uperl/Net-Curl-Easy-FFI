use Test2::V0 -no_srand => 1;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use lib 't/lib';
use Test2::Tools::MyTest;

subtest 'create exception' => sub {

  my $mock = mock 'Net::Swirl::CurlEasy';

  $mock->override( _clone => sub { undef } );

  my $curl = Net::Swirl::CurlEasy->new;

  my $ex = dies { $curl->clone }; my $line = __LINE__;

  is
    $ex,
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call line     => $line;
      call filename => __FILE__;
      call code     => Net::Swirl::CurlEasy::Const::SWIRL_CREATE_FAILED();
      call strerror => 'Could not create an instance of Net::Swirl::CurlEasy';
    },
    'clone failed';

  $mock->override( _new => sub { undef } );

  $ex = dies { Net::Swirl::CurlEasy->new }; $line = __LINE__;

  is
    $ex,
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call line     => $line;
      call filename => __FILE__;
      call code     => Net::Swirl::CurlEasy::Const::SWIRL_CREATE_FAILED();
      call strerror => 'Could not create an instance of Net::Swirl::CurlEasy';
    },
    'new failed';

};

subtest 'buffer-ref' => sub {

  my $curl = Net::Swirl::CurlEasy->new;

  my $ex = dies { $curl->send(\{ x => 1 }) }; my $line = __LINE__;

  is
    $ex,
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call line     => $line;
      call filename => __FILE__;
      call code => Net::Swirl::CurlEasy::Const::SWIRL_BUFFER_REF();
      call strerror => 'Buffer argument was not a reference to a string scalar';
    },
    'send failed';

  $ex = dies { $curl->recv(\{ x => 1 }) };  $line = __LINE__;

  is
    $ex,
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call line     => $line;
      call filename => __FILE__;
      call code => Net::Swirl::CurlEasy::Const::SWIRL_BUFFER_REF();
      call strerror => 'Buffer argument was not a reference to a string scalar';
    },
    'recv failed';

};

subtest 'internal' => sub {

  is
    dies { Net::Swirl::CurlEasy::Exception::Swirl->throw },
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call code => U();
      call strerror => 'Internal Net::Swirl::CurlEasy error';
    },
    'foo => internal';

};

keep_is_empty;

done_testing;
