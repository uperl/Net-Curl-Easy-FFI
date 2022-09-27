use Test2::V0 -no_srand => 1;
use Net::Swirl::CurlEasy;
use URI::file;
use Path::Tiny qw( path );

subtest 'very basic' => sub {
  my $curl = Net::Swirl::CurlEasy->new;
  isa_ok $curl, 'Net::Swirl::CurlEasy';

  my $url = URI::file->new_abs(__FILE__);
  try_ok { $curl->setopt( url => "$url" ) } "\$curl->setopt( url => '$url' )";

  my $content;

  try_ok {
    $curl->setopt( writefunction => sub {
      $content .= $_[0];
    });
  } "\$curl->setopt( writefunction => sub { ... } )";

  try_ok { $curl->perform } "\$curl->perform";

  is $content, path(__FILE__)->slurp_raw, 'content matches';

  try_ok { undef $curl } 'did not crash I guess?';
};

done_testing;
