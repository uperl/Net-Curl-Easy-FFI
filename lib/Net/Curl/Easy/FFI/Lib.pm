package Net::Curl::Easy::FFI::Lib {

  use warnings;
  use 5.020;
  use FFI::CheckLib 0.30 qw( find_lib_or_die );

# ABSTRACT: Private class for Net::Curl::Easy::FFI

=head1 SYNOPSIS

 $ perldoc Net::Curl::Easy::FFI

=head1 DESCRIPTION

There is nothing to see here.  Please see the main documentation page at
L<Archive::Libarchive>.

=cut

  sub lib
  {
    $ENV{NET_CURL_EASY_FFI_LIB_DLL} // find_lib_or_die( lib => 'curl',  symbol => ['curl_easy_setopt'], alien => ['Alien::curl'] );
  }

}

1;
