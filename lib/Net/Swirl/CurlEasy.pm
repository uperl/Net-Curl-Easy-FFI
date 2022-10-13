package Net::Swirl::CurlEasy {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use FFI::Platypus::Buffer ();
  use FFI::Platypus::Memory ();
  use Net::Swirl::CurlEasy::FFI;
  use FFI::C;
  use Scalar::Util ();
  use Ref::Util qw( is_ref is_scalarref is_arrayref );

# ABSTRACT: Perl bindings to curl's "easy" interface

=head1 SYNOPSIS

 use Net::Swirl::CurlEasy;
 
 Net::Swirl::CurlEasy
   ->new
   ->setopt( url => "https://metacpan.org" );
   ->perform;

=head1 DESCRIPTION

This is an alternative interface to curl's "easy" API interface.
It uses L<Alien::curl> to provide native TLS support on Windows and macOS,
and L<FFI::Platypus> to simplify development.

This module uses the C<Net::Swirl> prefix as swirl is a synonym I liked
that google suggested for "curl".  I felt the C<Net::Curl::> namespace was
already a little crowded, and I plan on adding additional modules in this
namespace for other parts of the C<libcurl> API.

If you are just beginning you should start out with the L<example section|/EXAMPLES>
below.

=cut

  our $ffi;

  BEGIN {
    $ffi = FFI::Platypus->new(
      api => 2,
      lib => [Net::Swirl::CurlEasy::FFI->lib],
    );
  }

  $ffi->type( 'object(Net::Swirl::CurlEasy)' => 'CURL' );
  $ffi->type( 'object(FFI::C::File)'         => 'FILE' );

  $ffi->attach( [ 'curl_free' => '_free' ] => ['opaque'] );

  FFI::C->ffi($ffi);

  package Net::Swirl::CurlEasy::C::CurlBlob {
    FFI::C->struct('curl_blob' => [
      data  => 'opaque',
      len   => 'size_t',
      flags => 'uint',
    ]);
  }

  $ffi->mangler(sub ($name) { "curl_slist_$name" });

  # There is almost certainly a better way to do this.
  package Net::Swirl::CurlEasy::C::CurlSlist {
    FFI::C->struct('curl_slist' => [
      _data => 'opaque',
      _next => 'opaque',
    ]);

    sub data ($self) { $ffi->cast( opaque => 'string', $self->_data ) }
    sub next ($self) { defined $self->_next ? $ffi->cast( opaque => 'curl_slist', $self->_next ) : undef }
  }

  package Net::Swirl::CurlEasy::C::CurlTlssessioninfo {
    FFI::C->struct('curl_tlssessioninfo' => [
      backend    => 'enum',
      _internals => 'opaque',
    ]);

    sub internals ($self) {
      Net::Swirl::CurlEasy::Exception::Swirl->throw(
        code  => Net::Swirl::CurlEasy::Const::SWIRL_NOT_IMPLEMENTED(),
        frame => 1,
      );
    }
  }

  package Net::Swirl::CurlEasy::C::CurlCertinfo {
    FFI::C->struct('curl_certinfo' => [
      num_of_certs => 'int',
      certinfo     => 'opaque',
    ]);

    sub to_perl ($self)
    {
      my $num = $self->num_of_certs;
      return [] unless $num > 0;
      return [
        # convert the Slist into a Perl list ref
        map { $_->as_list(1) }
        # convert each pointer to an Slist
        map { bless \$_, 'Net::Swirl::CurlEasy::Slist' }
        # cast the certinfo pointer to an array of the number of certificates of opaque
        # and flatten the reference
        $ffi->cast('opaque' => "opaque[$num]", $self->certinfo)->@*
      ];
    }
  }

  package Net::Swirl::CurlEasy::Slist {

    sub new ($, @items) {
      my $ptr;
      my $self = bless \$ptr, __PACKAGE__;
      $self->append($_) for @items;
      $self;
    }

    sub ptr ($self) { $$self }

    sub as_list ($self, $kill=0)
    {
      return [] unless defined $$self;
      my $struct = $ffi->cast( opaque => 'curl_slist', $$self );
      my @list;
      while(defined $struct)
      {
        push @list, $struct->data;
        $struct = $struct->next;
      }
      $$self = undef if $kill;
      \@list;
    }

    $ffi->attach( append => ['opaque', 'string'] => 'opaque' => sub ($xsub, $self, $value) {
      $$self = $xsub->($$self, $value);
      $self;
    });

    $ffi->attach( [ free_all => 'DESTROY' ] => ['opaque'] => 'void' => sub ($xsub, $self) {
      $xsub->($$self) if defined $$self;
      $$self = undef;
    });

  }

  $ffi->mangler(sub ($name) { "curl_easy_$name" });

  package Net::Swirl::CurlEasy::Exception::CurlCode {

    require Exception::FFI::ErrorCode;
    our @ISA = qw( Exception::FFI::ErrorCode::Base );  ## no critic (ClassHierarchies::ProhibitExplicitISA)

    $ffi->attach( strerror => ['enum'] => 'string' => sub ($xsub, $self) {
      $xsub->($self->{code});
    });

  }

  package Net::Swirl::CurlEasy::Exception::Swirl {

    use Exception::FFI::ErrorCode
      const_class => "Net::Swirl::CurlEasy::Const",
      codes       => {
        SWIRL_INTERNAL        => [ 0, "Internal Net::Swirl::CurlEasy error"                    ],
        SWIRL_CREATE_FAILED   => [ 1, "Could not create an instance of Net::Swirl::CurlEasy"   ],
        SWIRL_BUFFER_REF      => [ 2, "Buffer argument was not a reference to a string scalar" ],
        SWIRL_NOT_IMPLEMENTED => [ 3, "Not (yet) implemented"                                  ],
      };

    {
      my @swirl_codes = grep /^SWIRL_/, keys %Net::Swirl::CurlEasy::Const::;
      push @Net::Swirl::CurlEasy::Const::EXPORT_OK, @swirl_codes;
      $Net::Swirl::CurlEasy::Const::EXPORT_TAGS{swirl_errorcode} = \@swirl_codes;
      push $Net::Swirl::CurlEasy::Const::EXPORT_TAGS->{all}->@*, \@swirl_codes;
    }
  }

=head1 CONSTRUCTOR

=head2 new

 my $curl = Net::Swirl::CurlEasy->new;

This creates a new instance of this class.  The constructor can throw either
L<Net::Swirl::CurlEasy::Exception::Swirl|/Net::Swirl::CurlEasy::Exception::Swirl>
or
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
on failure.

( L<curl_easy_init|https://curl.se/libcurl/c/curl_easy_init.html> )

=cut

  sub _default_writefunction ($, $data, $fh) {
    print $fh $data;
  }

  $ffi->attach( [init => '_new'] => [] => 'opaque' );

  sub _set_perl_defaults ($self)
  {
    $self->setopt( writefunction  => \&_default_writefunction );
    $self->setopt( writedata      => \*STDOUT                 );
  }

  sub new ($class)
  {
    my $ptr = _new();
    Net::Swirl::CurlEasy::Exception::Swirl->throw(code => Net::Swirl::CurlEasy::Const::SWIRL_CREATE_FAILED(), frame => 1) unless $ptr;
    my $self = bless \$ptr, $class;
    $self->_set_perl_defaults;
    $self;
  }

  our %keep;

  $ffi->attach( [cleanup => 'DESTROY'] => ['CURL'] => 'void' => sub {
    my($xsub, $self) = @_;
    delete $keep{$$self};
    return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
    $xsub->($self);
  });

=head1 METHODS

Methods without a return value specified here return the L<Net::Swirl::CurlEasy> instance
so that they can be chained.

=head2 clone

 my $curl2 = $curl->clone;

This method will return a new L<Net::Swirl::CurlEasy> instance, a duplicate, using all the
options previously set in the original instance. Both instances can subsequently be used
independently.

The new instance will not inherit any state information, no connections, no SSL sessions
and no cookies. It also will not inherit any share object states or options (it will
be made as if CURLOPT_SHARE was set to C<undef>).

In multi-threaded programs, this function must be called in a synchronous way, the
original instance may not be in use when cloned.

L<Net::Swirl::CurlEasy::Exception::Swirl|/Net::Swirl::CurlEasy::Exception::Swirl>
or
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
on failure.

( L<curl_easy_duphandle|https://curl.se/libcurl/c/curl_easy_duphandle.html> )

=cut

  $ffi->attach( [duphandle => '_clone'] => ['CURL'] => 'opaque' );

  sub clone ($self)
  {
    my $ptr = _clone($self);
    Net::Swirl::CurlEasy::Exception::Swirl->throw(code => Net::Swirl::CurlEasy::Const::SWIRL_CREATE_FAILED(), frame => 1) unless $ptr;
    my $curl = bless \$ptr, ref($self);
    # we need to copy this, not use the same reference
    my %new_keep = $keep{$$self}->%*;
    $keep{$ptr} = \%new_keep;

    # return the new instance
    $curl;
  };

=head2 escape

 my $escaped = $curl->escape($unescaped);

This function converts the given input string to a URL encoded string and returns that
as a new allocated string. All input characters that are not a-z, A-Z, 0-9,  '-', '.',
'_' or '~' are converted to their "URL escaped" version (C<%NN> where NN is a two-digit
hexadecimal number).

( L<curl_easy_escape|https://curl.se/libcurl/c/curl_easy_escape.html> )

=cut

  $ffi->attach( escape => ['CURL','opaque','int'] => 'opaque' => sub ($xsub, $self, $buffer) {
    my($ptr, $size) = FFI::Platypus::Buffer::scalar_to_buffer($buffer);
    $ptr = $xsub->($self, $ptr, $size);
    my $string = $ffi->cast( 'opaque' => 'string', $ptr );
    _free($ptr);
    $string;
  });

=head2 getinfo

 my $value = $curl->getinfo($name);

Request internal information from the curl session with this function.  This will
throw
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
in the event of an error.

( L<curl_easy_getinfo|https://curl.se/libcurl/c/curl_easy_getinfo.html> )

What follows is a partial list of supported information.  The full list of
available information is listed in L<Net::Swirl::CurlEasy::Info>.

=head3 activesocket

 my $socket = $curl->getinfo('activesocket');

Returns the most recently active socket used for the transfer connection.  Will throw
an exception if the socket is no longer valid.  The active socket is typically only useful
in combination with L<connect_only|Net::Swirl::CurlEasy/connect_only>, which skips the
transfer phase, allowing you to use the socket to implement custom protocols.

( L<CURLINFO_ACTIVESOCKET|https://curl.se/libcurl/c/CURLINFO_ACTIVESOCKET.html> )

=head3 certinfo

 $curl->setopt(certinfo => 1);
      ->perform;
 my $certinfo = $curl->getinfo('certinfo');

For a TLS/SSL request, this will return information about the certificate chain, if you
set the L<certinfo option|Net::Swirl::CurlEasy::Options/certinfo>.  This will be returned
as list reference of list references.

( L<CURLINFO_CERTINFO|https://curl.se/libcurl/c/CURLINFO_CERTINFO.html> )

=head3 lastsocket

 my $socket = $curl->getinfo('activesocket');

This is just an alias for L<activesocket|/activesocket>.  In the C API  this info is
deprecated because it doesn't work correctly on 64 bit Windows.  Because it was deprecated
before L<Net::Swirl::CurlEasy> was written, this Perl API just makes this an alias
instead.

( L<CURLINFO_LASTSOCKET|https://curl.se/libcurl/c/CURLINFO_LASTSOCKET.html> )

=head3 private

 $curl->setopt( private => $data );
 my $data = $curl->getinfo( 'private' );

This field allows you to associate an arbitrary Perl data structure with the
L<Net::Swirl::CurlEasy> instance.  It isn't used by L<Net::Swirl::CurlEasy>
or C<libcurl> but may be useful for the application.

Note that in the C API this is a C<void *> pointer, but in this API it is a
Perl data structure.

( L<CURLINFO_PRIVATE|https://curl.se/libcurl/c/CURLINFO_PRIVATE.html> )

=head3 scheme

 my $scheme = $curl->getinfo('scheme');

URL scheme used for the most recent connection done.

( L<CURLINFO_SCHEME|https://curl.se/libcurl/c/CURLINFO_SCHEME.html> )

=head3 tls_session

 my $info = $curl->getinfo('tls_session');
 my $backend = $info->backend;
 my $internals = $info->internals;  # possibly implemented in a future version.

The C API for C<libcurl> returns an integer code for the SSL/TSL backend, and an internal
pointer which can be used to access get additional information about the session.  For now
only the former is available via this Perl API.  In the future there may be an interface
to the latter as well.

The meaning of the integer codes of the C<$backend> can be found here:
L<Net::Swirl::CurlEasy::Const/curl_sslbackend>.

The actual class that implements C<$info> may change in the future (including the class
name), but these two methods should be available (even if one just throws an exception).

( L<CURLINFO_TLS_SESSION|https://curl.se/libcurl/c/CURLINFO_TLS_SESSION.html> )

=head3 tls_ssl_ptr

 my $info = $curl->getinfo('tls_ssl_ptr');
 my $backend = $info->backend;
 my $internals = $info->internals;  # possibly implemented in a future version.

The C API for C<libcurl> returns an integer code for the SSL/TSL backend, and an internal
pointer which can be used to access get additional information about the session.  For now
only the former is available via this Perl API.  In the future there may be an interface
to the latter as well.

The meaning of the integer codes of the C<$backend> can be found here:
L<Net::Swirl::CurlEasy::Const/curl_sslbackend>.

Generally the L<tls_session option|/tls_session> is preferred when using the C API, but
until C<internals> is implemented it doesn't make any difference for the Perl API.

The actual class that implements C<$info> may change in the future (including the class
name), but these two methods should be available (even if one just throws an exception).

( L<CURLINFO_TLS_SSL_PTR|https://curl.se/libcurl/c/CURLINFO_TLS_SSL_PTR.html> )

=cut

  # Windows has a funny idea of what a socket type should be.
  # Actually so does Unix, but at least it is consistent lol
  if($^O eq 'MSWin32') {
    if($ffi->sizeof('opaque') == 8) {
      $ffi->type(uint64 => 'SOCKET');
    } else {
      $ffi->type(uint32 => 'SOCKET');
    }
  } else {
    $ffi->type(int => 'SOCKET');
  }

  $ffi->attach( [getinfo => '_getinfo_string'  ] => ['CURL','enum'] => ['string*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_double'  ] => ['CURL','enum'] => ['double*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_long'    ] => ['CURL','enum'] => ['long*'  ] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_off_t'   ] => ['CURL','enum'] => ['off_t*' ] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_socket'  ] => ['CURL','enum'] => ['SOCKET*'] => 'enum' );

  $ffi->attach( [getinfo => '_getinfo_certinfo'] => ['CURL','enum'] => ['opaque*'] => 'enum' => sub ($xsub, $self, $key_id, $value) {
    my $code = $xsub->($self, $key_id, \my $ptr);
    unless($code)
    {
      $$value = $ffi->cast('opaque', 'curl_certinfo', $ptr)->to_perl;
    }
    return $code;
  });

  $ffi->attach( [getinfo => '_getinfo_slist'   ] => ['CURL','enum'] => ['opaque*'] => 'enum' => sub ($xsub, $self, $key_id, $value) {
    my $code = $xsub->($self, $key_id, \my $ptr);
    unless($code)
    {
      my $slist = bless \$ptr, 'Net::Swirl::CurlEasy::Slist';
      $$value = $slist->as_list;
    }
    return $code;
  });

  $ffi->attach( [getinfo => '_getinfo_tlssessioninfo'] => ['CURL','enum'] => ['opaque*'] => 'enum' => sub ($xsub, $self, $key_id, $value) {
    my $code = $xsub->($self, $key_id, \my $ptr);
    unless($code)
    {
      $$value = $ffi->cast('opaque', 'curl_tlssessioninfo', $ptr);
    }
    return $code;
  });

  require Net::Swirl::CurlEasy::Info unless $Net::Swirl::CurlEasy::no_gen;

  our %info = (%info,
    activesocket => [5242924, \&_getinfo_socket        ],
    lastsocket   => [5242924, \&_getinfo_socket        ],
    certinfo     => [4194338, \&_getinfo_certinfo      ],
    tls_session  => [4194347, \&_getinfo_tlssessioninfo],
    tls_ssl_ptr  => [4194349, \&_getinfo_tlssessioninfo],
    private      => [1048597, sub ($self, $key_id, $value) { $$value = $keep{$$self}->{$key_id}; return 0 } ],
  );

  sub getinfo ($self, $key)
  {
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => 48, frame => 1) unless defined $info{$key};
    my($key_id, $xsub) = $info{$key}->@*;
    my $code = $xsub->($self, $key_id, \my $value);
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1) if $code;
    return $value;
  }

=head2 pause

 $curl->pause($bitmask);

Using this function, you can explicitly mark a running connection to get paused, and you can
unpause a connection that was previously paused.  For full details on how this method
works, review the documentation of the function from the C API below.  You can import the
appropriate integer constants for C<$bitmask> using the
L<:pause tag|Net::Swirl::CurlEasy::Const/CURLPAUSE> from L<Net::Swirl::CurlEasy::Const>.

Throws a
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode> on error.

( L<curl_easy_pause|https://curl.se/libcurl/c/curl_easy_pause.html> )

=cut

  $ffi->attach( pause => ['CURL','int'] => 'enum' => sub ($xsub, $self, $bitmask) {
    my $code = $xsub->($self, $bitmask);
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1) if $code;
    $self;
  });

=head2 perform

 $curl->perform;

Perform the curl request.  Throws a
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode> on error.

( L<curl_easy_perform|https://curl.se/libcurl/c/curl_easy_perform.html> )

=cut

  $ffi->attach( perform => ['CURL'] => 'enum' => sub {
    my($xsub, $self) = @_;
    my $code = $xsub->($self);
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1) if $code;
    $self;
  });

=head2 recv

 my $bytes_read = $curl->recv(\$buffer);
 my $bytes_read = $curl->recv(\$buffer, $size);

This function receives raw data from the established connection. You may use it together
with the L<send method|/send> to implement custom protocols. This functionality
can be particularly useful if you use proxies and/or SSL encryption: libcurl will take care
of proxy negotiation and connection setup.

C<$buffer> is a scalar that will be written to.  It should be passed in as a reference to scalar
If C<$size> is provided then C<$buffer> will be allocated with at least C<$size> bytes.

To establish a connection, set L<connect_only|/connect_only> to a true value before
calling the L<perform method|/perform>.  Note that this method does not work on connections
that were created without this option.

This method will normally return the actual number of bytes read, and the C<$buffer>
will be updated.  If there is no data to be read, then C<undef> will be returned.  You
can use C<select> with L<activesocket|/activesocket> to wait for data.

Wait on the socket only if C<recv> returns C<undef>.  The reason for this is C<libcurl>
or the SSL library may internally cache some data, therefore you should call C<recv>
until all data is read which would include any cached data.

Furthermore, if you wait on the socket and it tells you there is data to read C<recv>
may return C<undef> again if the only data that was read was for internal SSL processing,
and no other data is available.

This will throw
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
in the event of an error.

( L<curl_easy_recv|https://curl.se/libcurl/c/curl_easy_recv.html> )

=cut

  $ffi->attach( recv => ['CURL','opaque','size_t','size_t*'] => 'enum' => sub ($xsub, $self, $buf, $size_in=undef) {
    Net::Swirl::CurlEasy::Exception::Swirl->throw(code => Net::Swirl::CurlEasy::Const::SWIRL_BUFFER_REF(), frame => 1) unless is_ref $buf;
    $$buf = '' unless defined $$buf;
    Net::Swirl::CurlEasy::Exception::Swirl->throw(code => Net::Swirl::CurlEasy::Const::SWIRL_BUFFER_REF(), frame => 1) unless is_scalarref $buf;

    my $ptr;
    if(defined $size_in)
    {
      FFI::Platypus::Buffer::grow($$buf, $size_in);
      $ptr = FFI::Platypus::Buffer::scalar_to_pointer($$buf);
    }
    else
    {
      ($ptr,$size_in) = FFI::Platypus::Buffer::scalar_to_buffer($$buf);
    }

    my $code = $xsub->($self, $ptr, $size_in, \my $out_size);
    if($code != 0) {
      FFI::Platypus::Buffer::set_used_length($$buf, 0);
      return undef if $code == 81;
      Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1);
    }

    FFI::Platypus::Buffer::set_used_length($$buf, $out_size);

    return $out_size;
  });

=head2 reset

 $curl->reset;

Resets all options previously set via the L<setopt method|/setopt> to the
default values.  This puts the instance into the same state as when it was just
created.

It does not change the following information: live connections, the Session ID
cache, the DNS cache, the cookies, the shares or the alt-svc cache.

( L<curl_easy_reset|https://curl.se/libcurl/c/curl_easy_reset.html> )

=cut

  $ffi->attach( reset => ['CURL'] => sub ($xsub, $self) {
    $xsub->($self);
    delete $keep{$$self};
    $self->_set_perl_defaults;
    $self;
  });

=head2 send

 my $bytes_written = $curl->send(\$buffer);
 my $bytes_written = $curl->send(\$buffer, $offset);

This function sends arbitrary data over the established connection.  You may use it
together with the L<recv method|/recv> to implement custom protocols.  This
functionality can be particularly useful if you use proxies and/or SSL encryption:
libcurl will take care of proxy negotiation and connection setup.

C<$buffer> is the data to be sent.  It should be passed in as a reference to
a string scalar.  If C<$offset> is provided, then the first C<$offset> bytes will be
skipped.  This is useful if you are sending the rest of a buffer that was partially
sent on a previous call.

To establish a connection, set L<connect_only|/connect_only> to a true value before
calling the L<perform method|/perform>.  Note that this method does not work on connections
that were created without this option.

This method will normally return the actual number of bytes written.  If it is not
possible to send data right now, then C<undef> will be returned.  You can use
C<select> with L<activesocket|/activesocket> to wait for the connection to be ready.

This will throw
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
in the event of an error.

( L<curl_easy_send|https://curl.se/libcurl/c/curl_easy_send.html> )

=cut

  $ffi->attach( send => ['CURL','opaque','size_t','size_t*'] => 'enum' => sub ($xsub, $self, $buf, $offset=0) {
    Net::Swirl::CurlEasy::Exception::Swirl->throw(code => Net::Swirl::CurlEasy::Const::SWIRL_BUFFER_REF(), frame => 1) unless is_scalarref $buf;

    my ($ptr,$size_in) = FFI::Platypus::Buffer::scalar_to_buffer($$buf);

    my $code = $xsub->($self, $ptr+$offset, $size_in-$offset, \my $out_size);
    if($code != 0)
    {
      return undef if $code == 81;
      Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1);
    }

    return $out_size;
  });

=head2 setopt

 $curl->setopt( $option => $parameter );

Sets the given curl option.  Throws a
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
on error.

( L<curl_easy_setopt|https://curl.se/libcurl/c/curl_easy_setopt.html> )

What follows is a partial list of supported options.  The full list of
options can be found in L<Net::Swirl::CurlEasy::Options>.


=head3 connect_only

 $curl->setopt( connect_only => 1 );

Perform all the required proxy authentication and connection setup, but no data
transfer, and then return.  This is usually used in combination with
L<activesocket|Net::Swirl::CurlEasy/activesocket>.

This can be set to C<2> and if HTTP or WebSocket are used the request will be
done, along with all response headers before handing over control to you.

Transfers marked connect only will not reuse any existing connections and
connections marked connect only will not be allowed to get reused.

( L<CURLOPT_CONNECT_ONLY|https://curl.se/libcurl/c/CURLOPT_CONNECT_ONLY.html> )

=head3 followlocation

 $curl->setopt( followlocation => $bool );

Set this to 1 (the default is 0) to follow redirect responses.
The maximum number of redirects can be controlled by
L<maxredirs|/maxredirs>.

( L<CURLOPT_FOLLOWLOCATION|https://curl.se/libcurl/c/CURLOPT_FOLLOWLOCATION.html> )

=head3 headerdata

 $curl->setopt( headerdata => $headerdata);

This option sets the value of C<$headerdata> that is passed into the callback of
the L<headerfunction option|/headerfunction>.

If the L<headerfunction option|/headerfunction> is not set or set to C<undef>
and this option is set to a true value, then the header data will be written
instead to the L<writefunction callback|/writefunction>.

( L<CURLOPT_HEADERDATA|https://curl.se/libcurl/c/CURLOPT_HEADERDATA.html> )

=head3 headerfunction

 $curl->setopt( headerfunction => sub ($curl, $content, $headerdata) {
   ...
 });

This callback is called as each header is received.  The L<headerdata option|/headerdata>
is used to set C<$headerdata>.  For more details see the documentation for the
C API of this option:

( L<CURLOPT_HEADERFUNCTION|https://curl.se/libcurl/c/CURLOPT_HEADERFUNCTION.html> )

=head3 httpheader

 $curl->setopt( httpheader => \@headers );

This sets additional headers to add to your HTTP requests.  Each header B<must not>
be CRLF-terminated, because that will confuse the server.  If you provide a
header that C<libcurl> would normally add itself without a value (like C<Accept:>),
then it will remove that header from the request.

( L<CURLOPT_HTTPHEADER|https://curl.se/libcurl/c/CURLOPT_HTTPHEADER.html> )

=head3 maxredirs

 $curl->setopt( maxredirs => $max );

Sets the maximum number of redirects.  Setting the limit to C<0> will force
L<Net::Swirl::CurlEasy> refuse any redirect.  Set to C<-1> for an infinite
number of redirects.

( L<CURLOPT_MAXREDIRS|https://curl.se/libcurl/c/CURLOPT_MAXREDIRS.html> )

=head3 noprogress

 $curl->setopt( noprogress => $bool );

If C<$bool> is C<1> (the default) then the progress meter will not be used.
It also turns off calls to the L<xferinfofunction callback|/xferinfofunction>, so if
you want to use this callback set this value to C<0>.

( L<CURLOPT_NOPROGRESS|https://curl.se/libcurl/c/CURLOPT_NOPROGRESS.html> )

=head3 private

 $curl->setopt( private => $data );
 my $data = $curl->getinfo( 'private' );

This field allows you to associate an arbitrary Perl data structure with the
L<Net::Swirl::CurlEasy> instance.  It isn't used by L<Net::Swirl::CurlEasy>
or C<libcurl> but may be useful for the application.

Note that in the C API this is a C<void *> pointer, but in this API it is a
Perl data structure.

( L<CURLOPT_PRIVATE|https://curl.se/libcurl/c/CURLOPT_PRIVATE.html> )

=head3 postfields

 $curl->setopt( postfields => $postdata );

Set the full data to send in an HTTP POST operation.  If you use this option, then
C<curl> will set the C<Content-Type> to C<application/x-www-form-urlencoded>,
so if you want to use a different encoding, then you should specify that using
the L<httpheader option|/httpheader>.  You want to set the L<postfieldsize option|/postfieldsize>
before setting this one if you have any NULLs in your POST data.

( L<CURLOPT_POSTFIELDS|https://curl.se/libcurl/c/CURLOPT_POSTFIELDS.html> )

=head3 postfieldsize

 $curl->setopt( postfieldsize => $size );

The size of the POST data.  You want to set this before the L<postfields option|/postfields>
if you have any NULLs in your POST data.

( L<CURLOPT_POSTFIELDSIZE|https://curl.se/libcurl/c/CURLOPT_POSTFIELDSIZE.html> )

=head3 progressdata

 $curl->setopt( progressdata => $progressdata );

This is just an alias for the L<xferinfodata option|/xferinfodata>.

( L<CURLOPT_PROGRESSDATA|https://curl.se/libcurl/c/CURLOPT_PROGRESSDATA.html>)

=head3 progressfunction

 $curl->setopt( progressfunction => sub ($curl, $progressdata, $dltotal, $dlnow, $ultotal, $ulnow) {
   ...
 });

This is similar to the L<xferinfofunction callback|/xferinfofunction>, except C<$dltotal>,
C<$dlnow>, C<$ultotal> and C<$ulnow> are passed in as a floating point value instead
of as a 64 bit integer.  You are encouraged to use the L<xferinfofunction callback|/xferinfofunction>
if at all possible.

Note that this callback has the corresponding L<progressdata option|/progressdata>, but
that is actually an alias for the L<xferinfodata option|/xferinfodata>, so the C<$progressdata>
is actually the same as the C<$xferinfodata> that gets passed into that callback.

( L<CURLOPT_PROGRESSFUNCTION|https://curl.se/libcurl/c/CURLOPT_PROGRESSFUNCTION.html>)

=head3 readdata

 $curl->setopt( readdata => $readdata );

This is an arbitrary Perl data structure that will be passed into the
L<readfunction callback|/readfunction>.

( L<CURLOPT_READDATA|https://curl.se/libcurl/c/CURLOPT_READDATA.html> )

=head3 readfunction

 $curl->setopt( readfunction => sub ($curl, $maxsize, $readdata) {
   ...
 });

Used to read in request body for C<POST> and C<PUT> requests.  The C<$maxsize>
is the maximum size of the internal C<libcur> buffer, so you should not return
more than that number of bytes.  If you do return more than the maximum, then
only the first C<$maxsize> bytes will be passed on to C<libcurl>.  C<$readdata>
is the same object as passed in via the L<readdata option|/readdata>.

You can return either a string scalar or an array reference with three values.

 return $buffer;

For a regular string the entire string data will be passed back to C<libcurl>
up to the maximum of C<$maxsize> bytes.

 return [$buffer, $offset, $length];

For an array reference you can return a regular string scalar as the first
argument.  The other values C<$offset> and C<$length> are optional, and
determine a subset of the string that will be passed on to C<libcurl>.
If C<$offset> is provided then first C<$offset> bytes will be ignored.
If C<$length> is provided then only the C<$length> bytes after the C<$offset>
will be used.

This can be useful if you have a string scalar that is larger than C<$maxsize>,
but do not want to copy parts of the scalar before returning them.

For a string reference

( L<CURLOPT_READFUNCTION|https://curl.se/libcurl/c/CURLOPT_READFUNCTION.html> )

=head3 stderr

 $curl->setopt( stderr => $fp );

This option is for the output of the L<verbose option|/verbose> and the
default progress meter, which is enabled via the L<noprogress option|/noprogress>.

This option does NOT, as the name would suggest set C<stderr>, that is just
the default value for this option.

The default value for this is the C C<stderr> stream.  If you set this it
must be a C C<FILE *> pointer, which you can get using L<FFI::C::File>.
You probably also need to close the file after the transfer completes
in order to get the full output.  For example:

 use FFI::C::File;
 use Path::Tiny qw( path );
 
 my $fp = File::C::File->fopen("output.txt", "w");
 
 $curl->setopt( stderr => $fp )
       ->setopt( verbose => 1 )
       ->setopt( noprogress => 0 )
       ->perform;
 
 $fp->fclose;
 
 my $verbose_and_progress = path("output.txt")->slurp_raw;

Unfortunately the L<noprogress option|/noprogress> needs to be set to C<0>
for the L<progressfunction callback|/progressfunction> or the
L<xferinfofunction callback|/xferinfofunction>, but setting either of those
does not turn off the default progress meter (!) so when using those options
you may want to set this to something else.

( L<CURLOPT_STDERR|https://curl.se/libcurl/c/CURLOPT_STDERR.html> )

=head3 url

 $curl->setopt( url => $url );

The URL to work with.  This is the only required option.

( L<CURLOPT_URL|https://curl.se/libcurl/c/CURLOPT_URL.html> )

=head3 verbose

 $curl->setopt( verbose => 1 );

Set this to C<1> to make the library display a lot of verbose information about its
operations.  Useful for C<libcurl> and/or protocol debugging and understanding.

You hardly ever want to set this in production, you almost always want this when you
debug/report problems.

( L<CURLOPT_VERBOSE|https://curl.se/libcurl/c/CURLOPT_VERBOSE.html> )

=head3 writedata

 $curl->setopt( writedata => $writedata );

The C<writedata> option is used by the L<writefunction callback|/writefunction>.
This can be any Perl data type, but the default L<writefunction callback|/writefunction>
expects it to be a file handle, and the default value for C<writedata> is
C<STDOUT>.

( L<CURLOPT_WRITEDATA|https://curl.se/libcurl/c/CURLOPT_WRITEDATA.html> )

=head3 writefunction

 $curl->setopt( writefunction => sub ($curl, $content, $writedata) {
   ...
 });

The C<writefunction> callback will be called for each block of content
returned.  The content is passed as the second argument (the scalar uses
L<FFI::Platypus::Buffer/window> to efficiently expose the data
without having to copy it).  If an exception is thrown, then an
error will be passed back to curl (in the form of zero bytes
handled).

The callback also gets passed the L<Net::Swirl::CurlEasy> instance as
its first argument, and the L<writedata|/writedata> option as its third argument.

( L<CURLOPT_WRITEFUNCTION|https://curl.se/libcurl/c/CURLOPT_WRITEFUNCTION.html> )

=head3 xferinfodata

 $curl->setopt(xferinfodata => $xferinfodata );

The C<xferinfodata> option is used by the L<xferinfofunction callback|/xferinfofunction>.
This can be any Perl data type.  It is unused by C<libcurl> itself.

( L<CURLOPT_XFERINFODATA|https://curl.se/libcurl/c/CURLOPT_XFERINFODATA.html>)

=head3 xferinfofunction

 $curl->setopt(xferinfofunction => sub ($curl, $xferinfodata, $dltotal, $dlnow, $ultotal, $ulnow) {
   ...
 });

This gets called during the transfer "with a frequent interval".  C<$xferinfodata> is the
data passed into the L<xferinfodata option|/xferinfodata>.  The L<noprogress option|/noprogress>
must be set to C<0> otherwise this callback will not be called.

Note that if you set the L<noprogress option|/noprogress> to C<0> it will also turn on
C<curl>'s internal progress meter (!) which is probably not what you want.  You can work
around this by redirecting that output with the L<stderr option|/stderr>.

If this callback throws an exception, then the L<perform method|Net::Swirl::CurlEasy/perform>  will cancel the transfer
and throw a
L<Net::Swirl::CurlEasy::Exception::CurlCode|Net::Swirl::CurlEasy/Net::Swirl::CurlEasy::Exception::CurlCode>
exception.

( L<CURLOPT_XFERINFOFUNCTION|https://curl.se/libcurl/c/CURLOPT_XFERINFOFUNCTION.html> )

=cut

  $ffi->attach( [setopt => '_setopt_stringpoint'  ] => ['CURL','enum'] => ['string'] => 'enum' );
  $ffi->attach( [setopt => '_setopt_long'         ] => ['CURL','enum'] => ['long'  ] => 'enum' );
  $ffi->attach( [setopt => '_setopt_off_t'        ] => ['CURL','enum'] => ['off_t' ] => 'enum' );
  $ffi->attach( [setopt => '_setopt_opaque'       ] => ['CURL','enum'] => ['opaque'] => 'enum' );
  $ffi->attach( [setopt => '_setopt_FILE'         ] => ['CURL','enum'] => ['FILE'  ] => 'enum' );

  $ffi->attach( [setopt => '_setopt_slistpoint'   ] => ['CURL','enum'] => ['opaque'] => 'enum' => sub ($xsub, $self, $key_id, $items) {
    my $slist = Net::Swirl::CurlEasy::Slist->new($items->@*);
    $keep{$$self}->{$key_id} = $slist;
    $xsub->($self, $key_id, $slist->ptr);
  });

  $ffi->attach( [setopt => '_setopt_blob'         ] => ['CURL','enum'] => ['curl_blob'] => 'enum' => sub ($xsub, $self, $key_id, $blob_content) {
    my($data, $len) = FFI::Platypus::Buffer::scalar_to_buffer($blob_content);
    my $blob = Net::Swirl::CurlEasy::C::CurlBlob->new({
      data  => $data,
      len   => $len,
      flags => 1,   # CURL_BLOB_COPY
    });
    $xsub->($self, $key_id, $blob);
  });

  sub _setopt_xferinfofunction_cb_wrapper ($curl, $cb, $data_id) {
    Scalar::Util::weaken $curl;
    return $ffi->closure(sub ($, @data) {
      local $@ = '';
      eval {
        $cb->($curl, $keep{$$curl}->{$data_id}, @data);
      };
      if($@)
      {
        warn $@;
        return 1;
      }
      return 0x10000001; # CURL_PROGRESSFUNC_CONTINUE
    });
  }

  $ffi->attach( [setopt => '_setopt_xferinfofunction_cb'] => ['CURL','enum'] => ['(opaque,sint64,sint64,sint64,sint64)->int'] => 'enum' => sub ($xsub, $self, $key_id, $cb, $data_id) {
    my $closure = $keep{$$self}->{$key_id} = _setopt_xferinfofunction_cb_wrapper($self, $cb, $data_id);
    $xsub->($self, $key_id, $closure);
  });

  $ffi->attach( [setopt => '_setopt_progressfunction_cb'] => ['CURL','enum'] => ['(opaque,double,double,double,double)->int'] => 'enum' => sub ($xsub, $self, $key_id, $cb, $data_id) {
    my $closure = $keep{$$self}->{$key_id} = _setopt_xferinfofunction_cb_wrapper($self, $cb, $data_id);
    $xsub->($self, $key_id, $closure);
  });

  $ffi->attach( [setopt => '_setopt_writefunction_cb'] => ['CURL','enum'] => ['(opaque,size_t,size_t,opaque)->size_t'] => 'enum' => sub ($xsub, $self, $key_id, $cb, $data_id) {
    Scalar::Util::weaken $self;
    my $closure = $keep{$$self}->{$key_id} = $ffi->closure(sub ($ptr, $size, $nm, $) {
      FFI::Platypus::Buffer::window(my $data, $ptr, $size*$nm);
      local $@ = '';
      eval {
        $cb->($self, $data, $keep{$$self}->{$data_id})
      };
      # TODO: there should also be a callback to handle this
      if($@)
      {
        warn $@;
        return 0;
      }
      return $size*$nm;
    });
    $xsub->($self, $key_id, $closure);
  });

  $ffi->attach( [setopt => '_setopt_readfunction_cb'] => ['CURL','enum'] => ['(opaque,size_t,size_t,opaque)->size_t'] => 'enum' => sub ($xsub, $self, $key_id, $cb, $data_id) {
    Scalar::Util::weaken $self;
    my $closure = $keep{$$self}->{$key_id} = $ffi->closure(sub ($in_ptr, $in_size, $in_nm, $) {

      local $@ = '';
      my $max = $in_size * $in_nm;
      my $data = eval {
        $cb->($self, $max, $keep{$$self}->{$data_id});
      };
      # TODO: there should also be a callback to handle this
      if($@)
      {
        warn $@ if $@;
        # CURL_READFUNC_ABORT 0x10000000
        # this should cause perform to return CURLE_ABORTED_BY_CALLBACK
        return 0x10000000;
      }

      my $ptr;
      my $offset;
      my $size;

      if(is_arrayref $data)
      {
        $offset = $data->[1] // 0;
        my $buf_size;
        ($ptr, $buf_size) = FFI::Platypus::Buffer::scalar_to_buffer($data->[0]);

        $size   = $data->[2] // $buf_size;

        # if the offset is beyond the buffer, then set size to 0
        $size = 0 if $offset > $buf_size;

        # if the size extends beyond the buffer, then snip that part
        $size = $buf_size-$offset if $size > $buf_size-$offset;

        $ptr += $offset;
      }
      else
      {
        ($ptr, $size) = FFI::Platypus::Buffer::scalar_to_buffer($data);
        $size = $max if $size > $max;
      }

      FFI::Platypus::Memory::memcpy($in_ptr, $ptr, $size) if $size > 0;
      return $size;

    });

    $xsub->($self, $key_id, $closure);
  });

  require Net::Swirl::CurlEasy::Options unless $Net::Swirl::CurlEasy::no_gen;

  sub _function_data ($self, $key_id, $value)
  {
    $keep{$$self}->{$key_id} = $value;
    0;
  }

  our %opt = (%opt,
    private          => [ 1048597, \&_function_data                   ],
    postfields       => [ 10165, \&_setopt_stringpoint                ],
    stderr           => [ 10037, \&_setopt_FILE                       ],
    copypostfields   => [ 10165, \&_setopt_stringpoint                ],
    xferinfofunction => [ 20219, \&_setopt_xferinfofunction_cb, 10057 ],
    xferinfodata     => [ 10057, \&_function_data                     ],
    progressfunction => [ 20056, \&_setopt_progressfunction_cb, 10057 ],
    progressdata     => [ 10057, \&_function_data                     ],
    writefunction    => [ 20011, \&_setopt_writefunction_cb,    10001 ],
    writedata        => [ 10001, \&_function_data                     ],
    readfunction     => [ 20012, \&_setopt_readfunction_cb,     10009 ],
    readdata         => [ 10009, \&_function_data                     ],
    headerfunction   => [ 20079, \&_setopt_writefunction_cb,    10029 ],
    headerdata       => [ 10029, sub ($self, $key_id, $value) {
      $keep{$$self}->{$key_id} = $value;
      _setopt_opaque($self, $key_id, $value ? 1 : undef);
    }],
  );

  sub setopt ($self, $key, $value)
  {
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => 48, frame => 1) unless defined $opt{$key};
    my($key_id, $xsub, $data_id) = $opt{$key}->@*;
    my $code = $xsub->($self, $key_id, $value, $data_id ? ($data_id) : ());
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1) if $code;
    $self;
  }

=head2 unescape

 my $unescaped = $curl->unescape($escaped);

This function converts the given URL encoded input string to a "plain
string" and returns that in an allocated memory area. All input characters
that are URL encoded (C<%XX> where XX is a two-digit hexadecimal number) are
converted to their binary versions.

( L<curl_easy_unescape|https://curl.se/libcurl/c/curl_easy_unescape.html> )
=cut

  $ffi->attach( unescape => ['CURL','opaque','int','int*'] => 'opaque' => sub ($xsub, $self, $in) {
    return '' if length($in) == 0;
    my($in_ptr, $in_size) = FFI::Platypus::Buffer::scalar_to_buffer $in;
    my $out_ptr = $xsub->($self, $in_ptr, $in_size, \my $out_size);
    my $out = FFI::Platypus::Buffer::buffer_to_scalar($out_ptr, $out_size);
    _free($out_ptr);
    $out;
  });

=head2 upkeep

 $curl->upkeep;

Some protocols have "connection upkeep" mechanisms. These mechanisms
usually send some traffic on existing connections in order to keep them
alive; this can prevent connections from being closed due to overzealous
firewalls, for example.

This function must be explicitly called in order to perform the upkeep
work. The connection upkeep interval is set with
L<upkeep_interval_ms|Net::Swirl::CurlEasy::Options/upkeep_interval_ms>.

Throws a
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode>
on error.

( L<curl_easy_upkeep|https://curl.se/libcurl/c/curl_easy_upkeep.html> )

=cut

  $ffi->attach( upkeep => ['CURL'] => 'enum' => sub ($xsub, $self) {
    my $code = $xsub->($self);
    Net::Swirl::CurlEasy::Exception::CurlCode->throw(code => $code, frame => 1) if $code;
    $self;
  });

}

1;

=head1 EXCEPTIONS

In general methods should throw an exception object that is a subclass of L<Exception::FFI::ErrorCode>.
In some cases L<Net::Swirl::CurlEasy> calls modules that may throw string exceptions. When identified,
these should be converted into object exceptions (Please open an issue if you see this behavior).

Here is how you might catch exceptions using the new C<try> and C<isa> features:

 use Net::Swirl::CurlEasy qw( :all );
 use experimental qw( try isa );
 
 try {
   Net::Swirl::CurlEasy
     ->new
     ->setopt( url => 'https://alienfile.org' )
     ->perform;
 } catch ($e) {
   if($e isa Net::Swirl::CurlEasy::Exception::CurlCode) {
 
    # get the integer code
    my $code = $e->code;
    if($e->code == CURLE_UNSUPPORTED_PROTOCOL) {
      ...
    } elsif($e->code == CURLE_FAILED_INIT) {
      ...
    } elsif($e->code == CURLE_URL_MALFORMAT) {
      ...
    }
    ...


   } elsif($e isa Net::Swirl::CurlEasy::Exception::CurlCode) {
 
    if($e->code == SWIRL_CREATE_FAILED) {
      # the constructor failed to create an instance
      # rare
    } elsif($e->code == SWIRL_BUFFER_REF) {
      # passed the wrong arguments to a function that was
      # expecting a buffer
    }
 
   } else {
     # some exception not coming directly from libcurl or Swirl
   }
 }

=head2 base class

The base class for all exceptions that this class throws should be
L<Exception::FFI::ErrorCode::Base|Exception::FFI::ErrorCode>.  Please
see L<Exception::FFI::ErrorCode> for details on the base class.

=head2 Net::Swirl::CurlEasy::Exception::CurlCode

This is an exception that originated from C<libcurl> and has a corresponding C<CURLcode>.
It covers that vast majority of exceptions that you will see from this module.
It has these additional properties:

=over 4

=item code

This is the integer C<libcurl> code.  The full list of possible codes can be found here:
L<https://curl.se/libcurl/c/libcurl-errors.html>.  Note that typically an exception for
C<CURLE_OK> is not normally thrown so you should not see that value in an exception.

C<CURLE_AGAIN> (81) is usually caught by the L<send|/send> and L<recv|/recv> methods
which instead return C<undef> when socket is not ready.

If you want to use the constant names from the C API, you can import them from
L<Net::Swirl::CurlEasy::Const>.

=back

=head2 Net::Swirl::CurlEasy::Exception::Swirl

This is an exception that originates in L<Net::Swirl::CurlEasy> itself, or from
C<libcurl> in a way that no C<CURLcode> is provided.

=over 4

=item code

This is the integer error code.  You can import these from L<Net::Swirl::CurlEasy::Const>
using the C<:swirl_errorcode> or C<:all> tags.

=over 4

=item C<SWIRL_BUFFER_REF>

The L<send|/send> and L<recv|/recv> methods take a reference to a string scalar, and
you passed in something else.

=item C<SWIRL_CREATE_FAILED>

C<libcurl> was unable to create an instance.

=item C<SWIRL_INTERNAL>

An internal error.

=item C<SWIRL_NOT_IMPLEMENTED>

You called a method, function or option that is not yet implemented.

=back

=back

=head1 EXAMPLES

All of the examples are provided in the C<examples> subdirectory of this distribution.

These examples will work against this very simple PSGI app that you can run locally.

# EXAMPLE: examples/server.psgi

You can start it up by running C<plackup examples/server.psgi> and it will listen to port 5000
by default.  (If you are running on a recent version of macOS that also runs "AirPlay Receiver"
on that port, you can either change the port number and by passing C<-p 5001> to plackup, and
in each of these examples or by stopping "AirPlay Receiver" in the sharing dialog of the
control panel).

=head2 Simple GET

=head3 source

# EXAMPLE: examples/simple.pl

=head3 execute

 $ perl examples/simple.pl
 Hello World!

=head3 notes

This is a very simple GET.  If any method fails it will throw an exception, and methods that
do not otherwise return a useful value return the L<Net::Swirl::CurlEasy> object so they can
be chained like this.

The basic flow of most requests will work like this, once L<Net::Swirl::CurlEasy> instance is
created, you can set what options you want using L<setopt|/setopt>, and then call
L<perform|/perform> to make the actual request.  The only B<required> option is
L<url|/url>.  We also set L<followlocation|/followlocation> to follow any redirects, since
our server PSGI redirects C</> to C</hello-world>.  If you did not set this option, then you would get the 301 response
instead.  If you are used to using the C<curl> command line interface, this is equivalent
to its C<-L> option.

By default curl writes the body of the response to STDOUT, which is why we see it printed
when the example is run.

=head2 Debug Transfer With verbose Option

=head3 source

# EXAMPLE: examples/verbose.pl

=head3 execute

 $ perl examples/verbose.pl
 *   Trying 127.0.0.1:5000...
 * Connected to localhost (127.0.0.1) port 5000 (#0)
 > GET / HTTP/1.1
 Host: localhost:5000
 Accept: */*
 
 * Mark bundle as not supporting multiuse
 * HTTP 1.0, assume close after body
 < HTTP/1.0 301 Moved Permanently
 < Date: Mon, 03 Oct 2022 22:41:29 GMT
 < Server: HTTP::Server::PSGI
 < Location: /hello-world
 < Content-Length: 0
 <
 * Closing connection 0
 * Issue another request to this URL: 'http://localhost:5000/hello-world'
 * Hostname localhost was found in DNS cache
 *   Trying 127.0.0.1:5000...
 * Connected to localhost (127.0.0.1) port 5000 (#1)
 > GET /hello-world HTTP/1.0
 Host: localhost:5000
 Accept: */*
 
 * Mark bundle as not supporting multiuse
 * HTTP 1.0, assume close after body
 < HTTP/1.0 200 OK
 < Date: Mon, 03 Oct 2022 22:41:29 GMT
 < Server: HTTP::Server::PSGI
 < Content-Type: text/plain
 < Content-Length: 13
 <
 Hello World!
 * Closing connection 1

=head3 notes

If you set the L<verbose option|/verbose> you will get a lot of extra information about
the transfer.  This is equivalent to using the C<-v> flag with the C<curl> command.  You
normally would not want to do this programmatically with content that you want to capture,
but it can be useful for debugging transfers.

=head2 Capture Response Body With writedata

=head3 source

# EXAMPLE: examples/writedata.pl

=head3 execute

 $ perl examples/writedata.pl
 the server said 'Hello World!'

=head3 notes

Normally when using C<libcurl> programmatically you don't want to print the response body to
C<STDOUT>, you want to capture it in a variable to store or manipulate as appropriate.  The
L<writedata|/writedata> option allows you to do this.  The default implementation treats this option as
a file handle, so you can use any Perl object that supports the file handle interface.  Here
we use a handle that is redirecting to a scalar variable.  The reason the first example sends
output to C<STDOUT> is that C<STDOUT> is the default for this option!

=head2 Capture Response Body With writefunction

=head3 source

# EXAMPLE: examples/writefunction.pl

=head3 execute

 $ perl examples/writefunction.pl
 the server said 'Hello World!'

=head3 notes

You might want to route the data into a database or other store in chunks so that you do not
have to keep the entire response body in memory at one time.  In this example we use the
L<writefunction|/writefunction> option to define a callback function that will be called for
each chunk of the response.  The size of the chunks can vary depending on C<libcurl>.  You
could have a large chunk or even a chunk of zero bytes!

You may have noticed that the L<writefunction|/writefunction> callback takes two arguments,
the second of which we do not use.  This is the L<writedata|/writedata> option.  As mentioned
in the previous example, the default C<writefunction> callback treats this as a file handle,
but it could be any Perl data structure.

The default L<writefunction|/writefunction> callback looks like this:

 $curl->setopt( writefunction => sub ($, $data, $fh) {
   print $fh $data;
 });

=head2 Make a POST Request

=head3 source

# EXAMPLE: examples/post.pl

=head3 execute

 $ perl examples/post.pl
 {
   '1' => 'baz',
   'bar' => 'foo'
 }

=head3 notes

Here we are using the C<POST> method on the C</post> path on our little test server, which
just takes a C<POST> request as JSON object and reverses the keys for the values.  If we
do not specify the C<Content-Type>, then C<libcurl> will use C<application/x-www-form-urlencoded>,
so we explicitly set this to the MIME type for JSON.

Unless you are doing chunked encoding, you want to be careful to set the
L<postfieldsize option|/postfieldsize> before setting the L<postfields option|/postfields>,
if you have any NULLs in your request body, because C<curl> will assume a NULL terminated
string if you do not.

The rest of this should look very familiar, we gather up the response using the
L<writefunction callback|/writefunction> and decode it from JSON and print it out using
L<Data::Dumper>.

If you want to handle larger or streamed request bodies, then you will want to instead use
the L<readfunction callback|/readfunction> and possibly the L<readdata option|/readdata>.

=head2 Set or Remove Arbitrary Request Headers

=head3 source

# EXAMPLE: examples/req-header.pl

=head3 execute

 $ perl examples/req-header.pl
 {
   'host' => 'localhost:5000',
   'shoesize' => '10'
 }

=head3 notes

The L<httpheader option|Net::Swirl::CurlEasy::Options/httpheader> allows you to set and
remove arbitrary request headers.  In this example, we set the non-standard C<Shoesize>
header to the size C<10>.  We also set C<Accept> to nothing, which tells C<libcurl> not
to include this header.  (If you modified this example to not set that header  you would
see it come back as C<*/*>).

=head2 Get Response Headers

=head3 source

# EXAMPLE: examples/res-header.pl

=head3 execute

 $ perl examples/res-header.pl
 header: HTTP/1.0 200 OK
 header: Date: Tue, 04 Oct 2022 20:39:48 GMT
 header: Server: HTTP::Server::PSGI
 header: Content-Type: text/plain
 header: Foo: Bar
 header: Baz: 1
 header: Content-Length: 18
 header:
 Check the headers

=head3 notes

The L<headerfunction callback|/headerfunction> works a lot like the L<writefunction callback|/writefunction>
seen earlier.  It is called once for each header, so you can parse individual headers
inside the callback without having to wait for the rest of the header data.

We do not use it in this example, but the L<headerdata option|/headerdata> is used to
pass any Perl object into the callback, just like L<writedata option|/writedata> is
used to pass any Perl object into the L<writefunction callback|/writefunction>.

=head2 Parse the Entire Response Using Perl

=head3 source

# EXAMPLE: examples/res-parse.pl

=head3 execute

 $ perl examples/res-parse.pl
 The Foo Header Was: Bar
 The Content Was:    Check the headers

=head3 notes

If you do not set the L<headerfunction callback|/headerfunction> (or set it to C<undef>),
and set L<headerdata option|/headerdata> to a true value, then the header data will be
sent to the L<writefunction callback|/writefunction>.  This is a good way to capture and
parse the entire response.  Here we pass the raw response into the L<HTTP::Response>
class to parse it, which we can then use to interrogate it.

Note that we use the C<decoded_content> method on L<HTTP::Response> to make sure that the
content part of the response is correctly decoded.  In this case we could probably just
use content method instead, but this is a good example of how you could decode the content
of a HTTP response from C<libcurl> if you had to.

=head2 Get Information About the Request After the Transfer

=head3 source

# EXAMPLE: examples/getinfo.pl

=head3 execute

 $ perl examples/getinfo.pl
 Hello World!
 The Content-Type is: text/plain

=head3 notes

After calling the L<perform method|/perform> there is plethora of information available via
the L<getinfo method|/getinfo>.  The full list is available from L<Net::Swirl::CurlEasy::Info>
with more details on the C<curl> website: L<https://curl.se/libcurl/c/curl_easy_getinfo.html>.

In this example we get the C<Content-Type> and print it out.

=head2 Connect Securely With Mutual TLS/SSL Encryption and Verification

=head3 source

# EXAMPLE: examples/simplessl.pl

=head3 execute

 $ perl examples/simplessl.pl
 *   Trying 127.0.0.1:5001...
 * Connected to localhost (127.0.0.1) port 5001 (#0)
 * ALPN: offers h2
 * ALPN: offers http/1.1
 *  CAfile: examples/tls/Swirl-CA.crt
 *  CApath: none
 * SSL connection using TLSv1.2 / ECDHE-RSA-AES256-GCM-SHA384
 * ALPN: server accepted http/1.1
 * Server certificate:
 *  subject: CN=localhost
 *  start date: Oct  4 10:57:17 2022 GMT
 *  expire date: Jan  6 10:57:17 2025 GMT
 *  subjectAltName: host "localhost" matched cert's "localhost"
 *  issuer: CN=Snakeoil Swirl CA
 *  SSL certificate verify ok.
 > GET /hello-world HTTP/1.1
 Host: localhost:5001
 Accept: */*
 
 * Mark bundle as not supporting multiuse
 < HTTP/1.1 200 OK
 < Server: nginx/1.22.0
 < Date: Tue, 04 Oct 2022 12:53:32 GMT
 < Content-Type: text/plain
 < Content-Length: 13
 < Connection: keep-alive
 <
 Hello World!
 * Connection #0 to host localhost left intact

=head3 prereqs

Setting up a Certificate Authority (CA) and generating the appropriate certificates
is beyond the scope of this discussion, so we've pre-generated the appropriate
files in the C<examples/tls> directory so that the example can be run.  Hopefully
it is obvious that you should never use these files for in a production environment
since the "private" keys are completely public.

This directory also contains an C<nginx> configuration that will proxy to the plackup
server.  To start it you will need to install nginx and run:

 $ nginx -p examples/tls -c nginx.conf

=head3 notes

Once you have TLS/SSL certificates and keys and your server is correctly set up
it is pretty easy to use L<Net::Swirl::CurlEasy> so that it is secure using both
encryption and verification.

First we set these options:

=over 4

=item C<ssl_verifypeer>

We set this to C<1>, although this is the default.  If we don't want to verify
that the server has a valid certificate then we can set this to C<0>.  This
is roughly equivalent to C<curl>'s C<-k> option.

=item C<cainfo>

This is the Certificate Authority (CA) public certificate.  If you set
C<ssl_verifypeer> to false, then you do not need this.

=item C<sslcert> and C<sslkey>

This is the public client certificate and private key.  If the server does not
require client key, then you do not need these.

=item C<keypasswd>

This is the password with which the private client key was encrypted.  We use
the obviously terrible password `password` just to show how you would specify
a password.

=item C<verbose>

We also set the C<verbose> flag here once again just so that we can see some
of the details of the SSL/TLS interaction.

=back

Then once the transfer has completed using the L<perform method|/perform>,
we get the L<response code|Net::Swirl::CurlEasy::Info/response_code> to
ensure that the request was correctly accepted.  If the server does not like
our key, then it will return a 4xx error.

=head2 Implement Protocols With send and recv

=head3 source

# EXAMPLE: examples/connect-only.pl

=head3 execute

 $ perl examples/connect-only.pl
 HTTP/1.0 200 OK
 Date: Mon, 03 Oct 2022 20:27:07 GMT
 Server: HTTP::Server::PSGI
 Content-Type: text/plain
 Content-Length: 13
 
 Hello World!

=head3 notes

The combination of the L<connect_only option|/connect_only>, L<activesocket info|/activesocket>,
L<send method|/send> and L<recv method|/recv> allow you to implement your own protocols.  This can
be useful way to delegate TLS/SSL and proxies to this module to let you implement something a
custom protocol.  If you are trying to implement HTTP, as is demonstrated instead of using
C<curl>'s own HTTP transport then you may be doing something wrong, but this serves as a simple
example of how you would use this technique.

=over 4

=item 1

First of all we set the L<connect_only option|/connect_only> to C<1>.  C<curl> will establish
the connection (we don't use TLS/SSL or any proxies here, but if we did configure C<$curl> to
use them then they would be handled for us), but does not send the HTTP request.

=item 2

Next we have a utility function C<wait_on_socket> which waits for a socket to be either be ready
for writing, or have bytes ready to be read.

=item 3

We can use the L<getinfo method|/getinfo> with L<activesocket|/activesocket> to get the already
opened socket.  Note that we MUST NOT read or write to this socket directly, and should instead
use the L<send|/send> and L<recv|/recv> methods instead.

=item 4

Now we are ready to send our HTTP request using the L<send method|/send>.  This method will
return either C<undef> if the connection is not ready for writing, or the number of bytes that
were actually written.  The optional second argument to the L<send method|/send> is an offset
in the buffer.  This allows us to send just the remaining portion of the request if we have
already sent part of it.

=item 5

Finally we can use the L<recv method|/recv> to fetch the response.  Once again the data might
not be ready yet, and may come in chunks so we have to check the return value.  If it returns
C<undef> then we should once again wait on the socket, this time for bytes to read.  Otherwise
We can append the data to the response buffer that we are building up.  When there are no
more bytes to read we can assume the response is complete.

=back

=head1 CAVEATS

You should not store the L<Net::Swirl::CurlEasy> instance in any data structure that you
pass into L<Net::Swirl::CurlEasy> options like L</private> or any of the C<*data> options
because you will almost certainly cause a memory cycle where the L<Net::Swirl::CurlEasy>
cannot be freed (until exit).

 $curl->setopt( private => $curl );  # nooooo!

In addition the callbacks that you pass in should not use the L<Net::Swirl::CurlEasy>
instance from a closure for the same reason.  This is why the L<Net::Swirl::CurlEasy>
instance is passed into the callbacks.

 $curl->setopt( progressfunction => sub {
   $curl->getinfo( 'private' );  # nooooo!
 });

 $curl->setopt( progressfunction => sub ($callback_curl, @) {
   $callback_curl->getinfo( 'private' );  # okay
 });

=head1 SEE ALSO

=over 4

=item L<Net::Swirl::CurlEasy::Const>

Full list of constants used by L<Net::Swirl::CurlEasy>.

=item L<Net::Swirl::CurlEasy::Options>

Full list of options available to this API.

=item L<Net::Swirl::CurlEasy::Info>

Full list of information items available to this API.

=item L<Net::Curl::Easy>

Older more mature XS based interface to the C<libcurl> "easy" API.

=item L<Alien::curl>

L<Alien> used by this module if no system C<curl> can be found.

=item L<https://curl.se>

The C<curl> homepage.

=back

=cut
