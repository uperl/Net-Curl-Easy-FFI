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
my @info;
my %missing;
my $total = 0;
my $missing = 0;

my %option_init;
my %info_init;

{
  my $castxml = Clang::CastXML->new;
  my $header = $castxml->introspect($curl_h)->to_href;

  %option_init = 
    # convert into a hash, remove CURLOPT_ prefix for name
    map { $_->{name} =~ s/^CURLOPT_//r => $_->{init} }
    # get the inner list of the enum
    map { $_->{inner}->@* }
    # only consider objects called CURLoption (the enum), that have an inner list
    grep { defined $_->{name} && $_->{name} eq 'CURLoption' && defined $_->{inner} }
    # get all of the items in the header
    $header->{inner}->@*;

  %info_init = 
    # convert into a hash, remove CURLOPT_ prefix for name
    map { $_->{name} =~ s/^CURLINFO_//r => $_->{init} }
    # get the inner list of the enum
    map { $_->{inner}->@* }
    # only consider objects called CURLoption (the enum), that have an inner list
    grep { defined $_->{name} && $_->{name} eq 'CURLINFO' && defined $_->{inner} }
    # get all of the items in the header
    $header->{inner}->@*;
};

# These enum values aren't actually used, they just signify the
# start or end of the list.
delete $info_init{NONE};
delete $info_init{LASTONE};
delete $option_init{LASTENTRY};

foreach my $line ($curl_h->lines)
{
  if($line =~ /CURLOPT\(\s*CURLOPT_(\S+)\s*,\s*CURLOPTTYPE_(\S+)\s*,\s*\S+\s*\)/)
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
        c_name    => "CURLOPT_$name",
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

  if($line =~ /CURLINFO_(\S+)\s+=\s+CURLINFO_(\S+)/)
  {
    my $name = $1;
    my $type = $2;


    my $init = delete $info_init{$name};

    $total++;

    next if do {
      no warnings 'once';
      $Net::Swirl::CurlEasy::info{lc $name}
    };

    if($type =~ /^(STRING|DOUBLE|LONG|OFF_T|SLIST)$/ && $init)
    {
      push @info, {
        perl_name => lc $name,
        c_name    => "CURLINFO_$name",
        xsub_name => "_getinfo_@{[ lc $type ]}",
        init      => $init,
      };
    }
    else
    {
      push $missing{info}->{$type}->@*, "$name:$init";
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

foreach my $name (qw( Options Info ))
{
  $tt->process("$name.pm.tt", {
    curl => {
      options => \@options,
      infos => \@info,
      missing => {
        options => [sort map { s/:.*$//r } map { $_->@* } values $missing{options}->%*],
        infos   => [sort map { s/:.*$//r } map { $_->@* } values $missing{info}->%*  ]
      }
    },
  }, "lib/Net/Swirl/CurlEasy/$name.pm" ) or do {
    say "Error generating lib/Net/Swirl/CurlEasy/$name.pm @{[ $tt->error ]}";
    exit 2;
  };
}

push $missing{options}->{UNKNOWN}->@*, sort keys %option_init if %option_init;
push $missing{info}->{UNKNOWN}->@*, sort keys %info_init   if %info_init;

print YAML::Dump({ missing => \%missing });
say "missing: $missing/$total";
