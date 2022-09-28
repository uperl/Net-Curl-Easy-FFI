use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my $content = '';

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->setopt(writefunction => sub ($, $data, $) {
       $content .= $data;
     })
     ->perform;

# the server includes a new line
chomp $content;

say "the server said '$content'";
