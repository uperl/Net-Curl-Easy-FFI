#!/usr/bin/env perl

use warnings;
use 5.036;
use YAML ();
use Path::Tiny qw( path );
use Clang::CastXML;
use Template;
use Pod::Abstract;
use Const::Introspect::C;

$Net::Swirl::CurlEasy::no_gen =
$Net::Swirl::CurlEasy::no_gen = 1;
require Net::Swirl::CurlEasy;

my $curl_h = path('/usr/include/x86_64-linux-gnu/curl/curl.h');
my @options;
my @info;
my %missing;
my $total = 0;
my $missing = 0;

my @warnings;
my %option_init;
my %info_init;
my %str_enum;
my %opt_enum;
my @const;

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

  my @code =
    grep { $_->{name} =~ /^CURLE/ }
    # convert into a hash
    map { { name => $_->{name}, value =>  $_->{init} } }
    # get the inner list of the enum
    map { $_->{inner}->@* }
    # only consider objects called CURLoption (the enum), that have an inner list
    grep { defined $_->{name} && $_->{name} eq 'CURLcode' && defined $_->{inner} }
    # get all of the items in the header
    $header->{inner}->@*;

  push @const, {
    name      => 'CURLcode',
    url       => 'https://curl.se/libcurl/c/libcurl-errors.html',
    constants => \@code,
    tag       => ':errorcode',
  };

  my @ssl_backend =
    grep { $_->{name} =~ /^CURLSSLBACKEND_/ }
    # convert into a hash
    map { { name => $_->{name}, value =>  $_->{init} } }
    # get the inner list of the enum
    map { $_->{inner}->@* }
    # only consider objects called curl_sslbackend (the enum), that have an inner list
    grep { defined $_->{name} && $_->{name} eq 'curl_sslbackend' && defined $_->{inner} }
    # get all of the items in the header
    $header->{inner}->@*;

  push @const, {
    name      => 'curl_sslbackend',
    url       => 'https://curl.se/libcurl/c/CURLINFO_TLS_SSL_PTR.html',
    constants => \@ssl_backend,
    tag       => ':ssl_backend',
  };

  my @str_enum =
    # only consider the constants that we care about, extract the name, value and type
    map { $_->{name} =~ /^(CURLUSESSL|CURL_SSLVERSION|CURL_TIMECOND|CURLPROXY|CURLAUTH|CURL_NETRC|CURL_HTTP_VERSION|CURLFTPAUTH|CURLFTPMETHOD|CURL_RTSPREQ)_(.*)?/ ?
             ({ name => lc($2), value => $_->{init}, type => lc($1) }) : () }
    # get the inner list of the enum
    map { $_->{inner}->@* }
    # consider any enum, since these enums are un-named, that have an inner list
    grep { defined $_->{_class} && $_->{_class} eq 'Enumeration' && defined $_->{inner} }
    # get all of the items in the header
    $header->{inner}->@*;

  foreach my $const (@str_enum)
  {
    my $type  = $const->{type};
    my $name  = lc $const->{name};
    my $value = $const->{value};

    if($type eq 'curl_sslversion')
    {
      next if $name =~ /^max_/;
    }

    next if $name eq 'last';

    $type =~ s/^curl_?/curl_/;

    push $str_enum{$type}->{values}->@*, { name => $name, value => $value };
    $str_enum{$type}->{type} = $type;
  }

  $str_enum{curl_usessl}->{opt}       = [ 'use_ssl'              ];
  $str_enum{curl_sslversion}->{opt}   = [ 'sslversion'           ];
  $str_enum{curl_timecond}->{opt}     = [ 'timecondition'        ];
  $str_enum{curl_proxy}->{opt}        = [ 'proxytype'            ];
  $str_enum{curl_netrc}->{opt}        = [ 'netrc'                ];
  $str_enum{curl_http_version}->{opt} = [ 'http_version'         ];
  $str_enum{curl_ftpauth}->{opt}      = [ 'ftpsslauth'           ];
  $str_enum{curl_ftpmethod}->{opt}    = [ 'ftp_filemethod'       ];
  $str_enum{curl_rtspreq}->{opt}      = [ 'rtsp_request'         ];

  foreach my $enum (values %str_enum)
  {
    foreach my $opt ($enum->{opt}->@*)
    {
      $opt_enum{$opt} = $enum;
    }
  }

};

{
  my $c = Const::Introspect::C->new(
    headers => ['curl/curl.h'],
  );

  my @pause;

  foreach my $const ($c->get_macro_constants)
  {
    if($const->name =~ /^CURLPAUSE_/)
    {
      push @pause, {
        name  => $const->name,
        value => $const->value,
      };
    }
  }

  push @const, {
    name      => 'CURLPAUSE',
    url       => 'https://curl.se/libcurl/c/curl_easy_pause.html',
    constants => [sort { $a->{name} cmp $b->{name} } @pause],
    tag       => ':pause',
  };
}

my %hand_pod;

{
  my $pa = Pod::Abstract->load_file("lib/Net/Swirl/CurlEasy.pm");
  $_->detach for $pa->select('//#cut');

  foreach my $option ($pa->select('/head1[@heading =~ {METHODS}]/head2[@heading =~ {setopt}]/head3'))
  {
    my $name = $option->param('heading')->pod;
    my $pod = $option->pod =~ s/=head3/=head2/r;
    chomp $pod;
    $hand_pod{option}->{$name} = $pod;
  }

  foreach my $option ($pa->select('/head1[@heading =~ {METHODS}]/head2[@heading =~ {getinfo}]/head3'))
  {
    my $name = $option->param('heading')->pod;
    my $pod = $option->pod =~ s/=head3/=head2/r;
    chomp $pod;
    $hand_pod{info}->{$name} = $pod;
  }
}

# These enum values aren't actually used, they just signify the
# start or end of the list.
delete $info_init{NONE};
delete $info_init{LASTONE};
delete $option_init{LASTENTRY};

my %aliases = (
  option => {
    xferinfodata => 'progressdata',
  },
);

foreach my $line ($curl_h->lines)
{
  if($line =~ /CURLOPT\(\s*CURLOPT_(\S+)\s*,\s*CURLOPTTYPE_(\S+)\s*,\s*\S+\s*\)/)
  {
    my $name = $1;
    my $type = $2;

    my $init = delete $option_init{$name};

    $total++;

    next if $name =~ /^OBSOLETE/;

    if(($type =~ /^(STRINGPOINT|LONG|OFF_T|SLISTPOINT|BLOB)$/ || $Net::Swirl::CurlEasy::opt{lc $name} || $opt_enum{lc $name}) && $init)
    {
      my $xsub_name;

      my %option = (
        perl_name => lc $name,
        c_name    => "CURLOPT_$name",
        init      => $init,
        hand_pod  => delete $hand_pod{option}->{lc $name},
        hand_code => !!$Net::Swirl::CurlEasy::opt{lc $name},
      );

      if(my $enum = $opt_enum{lc $name})
      {
        $option{xsub_name} = "_setopt_@{[ $enum->{type} ]}";
        $option{enum} = [ map { $_->{name} } $enum->{values}->@* ];
      }
      else
      {
        $option{xsub_name} = "_setopt_@{[ lc $type ]}";
      }

      push @options, \%option;

      # progressdata is an alias for xinfodata
      if(my $alias = delete $aliases{option}->{lc $name})
      {
        my %option = %option;
        $option{perl_name} = $alias;
        $option{c_name}    = 'CURLOPT_PROGRESSDATA';
        $option{hand_pod}  = delete $hand_pod{option}->{$alias};
        $option{hand_code} = !!$Net::Swirl::CurlEasy::opt{$alias};
        push @options, \%option;
      }

      if(!!$Net::Swirl::CurlEasy::opt{lc $name})
      {
        push @warnings, "Integer opt mismatch for @{[ $name ]} (@{[ $Net::Swirl::CurlEasy::opt{lc $name}->[0] ]}, $init)"
          if $Net::Swirl::CurlEasy::opt{lc $name}->[0] != $init;
      }

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

    if(($type =~ /^(STRING|DOUBLE|LONG|OFF_T|SLIST)$/ || $Net::Swirl::CurlEasy::info{lc $name}) && $init)
    {
      push @info, {
        perl_name => lc $name,
        c_name    => "CURLINFO_$name",
        xsub_name => "_getinfo_@{[ lc $type ]}",
        init      => $init,
        hand_pod  => delete $hand_pod{info}->{lc $name},
        hand_code => !!$Net::Swirl::CurlEasy::info{lc $name},
      };

      if(!!$Net::Swirl::CurlEasy::info{lc $name})
      {
        push @warnings, "Integer info mismatch for @{[ $name ]} (@{[ $Net::Swirl::CurlEasy::info{lc $name}->[0] ]}, $init)"
          if $Net::Swirl::CurlEasy::info{lc $name}->[0] != $init;
      }

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

{

  my %data = (
    curl => {
      options => \@options,
      infos => \@info,
      missing => {
        options => [sort map { s/:.*$//r } map { $_->@* } values $missing{options}->%*],
        infos   => [sort map { s/:.*$//r } map { $_->@* } values $missing{info}->%*  ]
      },
      const => \@const,
      enum => [sort { $a->{type} cmp $b->{type} } values %str_enum ],
    }
  );

  foreach my $name (qw( options infos ))
  {
    if($data{curl}->{missing}->{$name}->@* == 0)
    {
      delete $data{curl}->{missing}->{$name};
    }
  }

  foreach my $name (qw( Const Options Info ))
  {
    $tt->process("$name.pm.tt", \%data, "lib/Net/Swirl/CurlEasy/$name.pm" ) or do {
      say "Error generating lib/Net/Swirl/CurlEasy/$name.pm @{[ $tt->error ]}";
      exit 2;
    };
  }
}

push $missing{options}->{UNKNOWN}->@*, sort keys %option_init if %option_init;
push $missing{info}->{UNKNOWN}->@*, sort keys %info_init   if %info_init;
push $missing{options}->{pod}->@*, sort keys $hand_pod{option}->%* if $hand_pod{option}->%*;
push $missing{info}->{pod}->@*, sort keys $hand_pod{info}->%* if $hand_pod{info}->%*;

print YAML::Dump({ missing => \%missing, warnings => \@warnings });
say "missing: $missing/$total";
