use Test2::V0 -no_srand => 1;
use 5.020;

package MyTest1 {

  use Net::Swirl::CurlEasy::Const;

  Test2::V0::not_imported_ok('CURLE_OK');
  Test2::V0::not_imported_ok('CURLE_LAST');
  Test2::V0::not_imported_ok('CURLPAUSE_CONT');

}

package MyTest2 {

  use Net::Swirl::CurlEasy::Const qw( :all );

  Test2::V0::imported_ok('CURLE_OK');
  Test2::V0::not_imported_ok('CURLE_LAST');
  Test2::V0::imported_ok('CURLPAUSE_CONT');

}

package MyTest3 {

  use Net::Swirl::CurlEasy::Const qw( :errorcode );

  Test2::V0::imported_ok('CURLE_OK');
  Test2::V0::not_imported_ok('CURLE_LAST');
  Test2::V0::not_imported_ok('CURLPAUSE_CONT');

}

package MyTest4 {

  use Net::Swirl::CurlEasy::Const qw( :pause );

  Test2::V0::not_imported_ok('CURLE_OK');
  Test2::V0::not_imported_ok('CURLE_LAST');
  Test2::V0::imported_ok('CURLPAUSE_CONT');

}

done_testing;
