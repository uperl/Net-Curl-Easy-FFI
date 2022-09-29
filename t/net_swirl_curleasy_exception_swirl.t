use Test2::V0 -no_srand => 1;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

subtest 'create exception' => sub {

  my $mock = mock 'Net::Swirl::CurlEasy';

  $mock->override( _clone => sub { undef } );

  my $curl = Net::Swirl::CurlEasy->new;

  is
    dies { $curl->clone },
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call code => 'create-failed';
      call strerror => 'Could not create an instance of Net::Swirl::CurlEasy';
    },
    'clone failed';

  $mock->override( _new => sub { undef } );

  is
    dies { Net::Swirl::CurlEasy->new },
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call code => 'create-failed';
      call strerror => 'Could not create an instance of Net::Swirl::CurlEasy';
    },
    'new failed';

};

subtest 'internal' => sub {

  is
    dies { Net::Swirl::CurlEasy::Exception::Swirl::throw('foo') },
    object {
      call [ isa => 'Net::Swirl::CurlEasy::Exception::Swirl' ] => T();
      call code => 'internal';
      call strerror => 'Internal Net::Swirl::CurlEasy error';
    },
    'foo => internal';

};

done_testing;
