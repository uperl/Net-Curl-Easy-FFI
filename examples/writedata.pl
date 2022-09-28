use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my $content;
open my $wd, '>', \$content;

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->setopt(writedata => $wd)
     ->perform;

# the server includes a new line
chomp $content;

say "the server said '$content'";
