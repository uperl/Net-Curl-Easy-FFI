#!/usr/bin/env perl

use warnings;
use 5.036;
use File::chdir;
use Path::Tiny qw( path );
use Ref;

my $exit = 0;

foreach my $version (ref_config->{LATEST})
{
  local $ENV{NET_SWIRL_CURL_DLL} = do {
    local $CWD = "/opt/curl/$version/lib";
    my $so = "libcurl.so";
    $so = readlink $so if -l $so;
    path($so)->absolute;
  };

  say "libcurl $version so=$ENV{NET_SWIRL_CURL_DLL}";

  system prove => '-lvm';
  $exit = 2 if $?;
}

exit $exit;
