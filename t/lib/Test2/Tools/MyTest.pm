use warnings;
use 5.020;
use experimental qw( signatures );

package Test2::Tools::MyTest {

  use Exporter qw( import );
  use Test2::Tools::Compare ();
  use Test2::API qw( context );

  our @EXPORT = qw( keep_is_empty );

  sub keep_is_empty ($name=undef) {
    $name = "%keep is empty";

    Test2::Tools::Compare::is \%Net::Swirl::CurlEasy::keep, {}, $name;
  }

}

1;
