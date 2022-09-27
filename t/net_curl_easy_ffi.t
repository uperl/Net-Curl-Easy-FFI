use Test2::V0 -no_srand => 1;
use  experimental qw( signatures );
use Net::Curl::Easy::FFI;
use URI::file;
use Path::Tiny qw( path );

subtest 'very basic' => sub {
  my $curl = Net::Curl::Easy::FFI->new;
  isa_ok $curl, 'Net::Curl::Easy::FFI';

  my $url = URI::file->new_abs(__FILE__);
  my $code = $curl->setopt( url => "$url" );
  is $code, 0, "\$curl->setopt( url => '$url' )";

  my $content;
  $code = $curl->setopt( writefunction => sub {
    $content .= $_[0];
  });
  is $code, 0, "\$curl->setopt( writefunction => sub { ... } )";

  $code = $curl->perform;
  is $code, 0, "\$curl->perform";

  is $content, path(__FILE__)->slurp_raw, 'content matches';

  undef $curl;
  pass 'did not crash I guess?';
};

done_testing;
