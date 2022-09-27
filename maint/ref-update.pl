#!/usr/bin/env perl

use warnings;
use 5.036;
use YAML ();
use Path::Tiny qw( path );
use Clang::CastXML;
use Template;

$Net::Swirl::CurlEasy::no_gen =
$Net::Swirl::CurlEasy::no_gen = 1;
require Net::Swirl::CurlEasy;

my $curl_h = path('/usr/include/x86_64-linux-gnu/curl/curl.h');
my @options;
my %missing;
my $total = 0;
my $missing = 0;

my %option_init = do {
  my $castxml = Clang::CastXML->new;
  my $header = $castxml->introspect($curl_h)->to_href;

  # convert into a hash, remove CURLOPT_ prefix for name
  map { $_->{name} =~ s/^CURLOPT_//r => $_->{init} }
  # get the inner list of the enum
  map { $_->{inner}->@* }
  # only consider objects called CURLoption (the enum), that have an inner list
  grep { defined $_->{name} && $_->{name} eq 'CURLoption' && defined $_->{inner} }
  # get all of the items in the header
  $header->{inner}->@*
};

foreach my $line ($curl_h->lines)
{
  if($line =~ /CURLOPT\(\s*CURLOPT_(\S*)\s*,\s*CURLOPTTYPE_(\S+)\s*,\s*\S+\s*\)/)
  {
    my $name = $1;
    my $type = $2;

    my $init = delete $option_init{$name};

    $total++;

    next if $name =~ /^OBSOLETE/;
    next if do {
      no warnings 'once';
      $Net::Swirl::CurlEasy::opt{lc $name}
    };

    if($type =~ /^(STRINGPOINT|LONG|OFF_T|SLISTPOINT)$/ && $init)
    {
      push @options, {
        perl_name => lc $name,
        #c_name    => "CURLOPT_$name",
        xsub_name => "_setopt_@{[ lc $type ]}",
        init      => $init,
      };
    }
    else
    {
      push $missing{options}->{$type}->@*, "$name:$init";
      $missing++;
    }

  }
}

@options = sort { $a->{perl_name} cmp $b->{perl_name} } @options;

my $tt = Template->new({
  INCLUDE_PATH => [path(__FILE__)->parent->child('tt')->stringify],
  FILTERS => {
    type => sub ($name) {
      $name ne '' ? "'$name'" : 'undef';
    },
  },
});

$tt->process('Option.pm.tt', {
  curl => { options => \@options },
}, "lib/Net/Swirl/CurlEasy/Options.pm" ) or do {
  say "Error generating lib/Net/Swirl/CurlEasy/Options.pm @{[ $tt->error ]}";
  exit 2;
};


push $missing{options}->{UNKNOWN}->@*, sort keys %option_init;

print YAML::Dump({ options => \@options });
print YAML::Dump({ missing => \%missing });
say "missing: $missing/$total";
