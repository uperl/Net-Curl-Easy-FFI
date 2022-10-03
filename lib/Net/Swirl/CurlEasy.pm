package Net::Swirl::CurlEasy {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use FFI::Platypus::Buffer qw( window scalar_to_buffer buffer_to_scalar );
  use Net::Swirl::CurlEasy::FFI;
  use FFI::C;
  use Ref::Util qw( is_ref is_scalarref );

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

  my $ffi;

  BEGIN {
    $ffi = FFI::Platypus->new(
      api => 2,
      lib => [Net::Swirl::CurlEasy::FFI->lib],
    );
  }

  $ffi->type( 'object(Net::Swirl::CurlEasy)' => 'CURL' );

  $ffi->attach( [ 'curl_free' => '_free' ] => ['opaque'] );

  $ffi->mangler(sub ($name) { "curl_slist_$name" });

  # There is almost certainly a better way to do this.
  package Net::Swirl::CurlEasy::SlistStruct {
    FFI::C->ffi($ffi);
    FFI::C->struct([
      _data => 'opaque',
      _next => 'opaque',
    ]);

    sub data ($self) { $ffi->cast( opaque => 'string', $self->_data ) }
    sub next ($self) { defined $self->_next ? $ffi->cast( opaque => 'slist_struct_t', $self->_next ) : undef }

  }

  package Net::Swirl::CurlEasy::Slist {

    sub new ($, @items) {
      my $ptr;
      my $self = bless \$ptr, __PACKAGE__;
      $self->append($_) for @items;
      $self;
    }

    sub ptr ($self) { $$self }

    sub as_list ($self)
    {
      return [] unless defined $$self;
      my $struct = $ffi->cast( opaque => 'slist_struct_t', $$self );
      my @list;
      while(defined $struct)
      {
        push @list, $struct->data;
        $struct = $struct->next;
      }
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

  package Net::Swirl::CurlEasy::Exception {

    use overload
      '""' => sub { shift->as_string },
      bool => sub { 1 }, fallback => 1;

    sub new ($class)
    {
      my($package, $filename, $line) = caller(2);
      bless {
        package  => $package,
        filename => $filename,
        line     => $line,
      }, $class;
    }

    sub code     ($self) { $self->{code}     }
    sub package  ($self) { $self->{package}  }
    sub filename ($self) { $self->{filename} }
    sub line     ($self) { $self->{line}     }

    sub strerror ($self)
    {
      die "not implemented";
    }

    sub as_string ($self)
    {
      sprintf "%s at %s line %s.", $self->strerror, $self->filename, $self->line;
    }

  }

  package Net::Swirl::CurlEasy::Exception::CurlCode {

    our @ISA = qw( Net::Swirl::CurlEasy::Exception );  ## no critic (ClassHierarchies::ProhibitExplicitISA)

    sub throw ($code)
    {
      my $self = __PACKAGE__->new;
      $self->{code} = $code;
      die $self;
    }

    $ffi->attach( strerror => ['enum'] => 'string' => sub ($xsub, $self) {
      $xsub->($self->{code});
    });

  }

  package Net::Swirl::CurlEasy::Exception::Swirl {

    our @ISA = qw( Net::Swirl::CurlEasy::Exception );  ## no critic (ClassHierarchies::ProhibitExplicitISA)

    sub throw ($code)
    {
      my $self = __PACKAGE__->new;
      unless($code =~ /^(create-failed|internal|buffer-ref)$/) {
        throw('internal');
      }
      $self->{code} = $code;
      die $self;
    }

    sub strerror ($self)
    {
      if($self->{code} eq 'create-failed')
      {
        return "Could not create an instance of Net::Swirl::CurlEasy";
      }
      elsif($self->{code} eq 'buffer-ref')
      {
        return "Buffer argument was not a reference to a string scalar";
      }
      else
      {
        return "Internal Net::Swirl::CurlEasy error";
      }
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

  sub new ($class)
  {
    my $ptr = _new();
    Net::Swirl::CurlEasy::Exception::Swirl::throw('create-failed') unless $ptr;
    my $self = bless \$ptr, $class;
    $self->setopt( writefunction => \&_default_writefunction );
    $self->setopt( writedata     => \*STDOUT );
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
    Net::Swirl::CurlEasy::Exception::Swirl::throw('create-failed') unless $ptr;
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
    my($ptr, $size) = scalar_to_buffer $buffer;
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


=head3 lastsocket

 my $socket = $curl->getinfo('activesocket');

This is just an alias for L<activesocket|/activesocket>.  In the C API  this info is
deprecated because it doesn't work correctly on 64 bit Windows.  Because it was deprecated
before L<Net::Swirl::CurlEasy> was written, this Perl API just makes this an alias
instead.

( L<CURLINFO_LASTSOCKET|https://curl.se/libcurl/c/CURLINFO_LASTSOCKET.html> )

=head3 scheme

 my $scheme = $curl->getinfo('scheme');

URL scheme used for the most recent connection done.

( L<CURLINFO_SCHEME|https://curl.se/libcurl/c/CURLINFO_SCHEME.html> )

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

  $ffi->attach( [getinfo => '_getinfo_string'] => ['CURL','enum'] => ['string*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_double'] => ['CURL','enum'] => ['double*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_long'  ] => ['CURL','enum'] => ['long*'  ] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_off_t' ] => ['CURL','enum'] => ['off_t*' ] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_socket'] => ['CURL','enum'] => ['SOCKET*'] => 'enum' );

  $ffi->attach( [getinfo => '_getinfo_slist' ] => ['CURL','enum'] => ['opaque*'] => 'enum' => sub ($xsub, $self, $key_id, $value) {
    my $code = $xsub->($self, $key_id, \my $ptr);
    unless($code)
    {
      my $slist = bless \$ptr, 'Net::Swirl::CurlEasy::Slist';
      $$value = $slist->as_list;
    }
    return $code;
  });

  require Net::Swirl::CurlEasy::Info unless $Net::Swirl::CurlEasy::no_gen;

  our %info = (%info,
    activesocket => [5242924, \&_getinfo_socket],
    lastsocket   => [5242924, \&_getinfo_socket],
  );

  sub getinfo ($self, $key)
  {
    Net::Swirl::CurlEasy::Exception::CurlCode::throw(48) unless defined $info{$key};
    my($key_id, $xsub) = $info{$key}->@*;
    my $code = $xsub->($self, $key_id, \my $value);
    Net::Swirl::CurlEasy::Exception::CurlCode::throw($code) if $code;
    return $value;
  }

=head2 perform

 $curl->perform;

Perform the curl request.  Throws a
L<Net::Swirl::CurlEasy::Exception::CurlCode|/Net::Swirl::CurlEasy::Exception::CurlCode> on error.

( L<curl_easy_perform|https://curl.se/libcurl/c/curl_easy_perform.html> )

=cut

  $ffi->attach( perform => ['CURL'] => 'enum' => sub {
    my($xsub, $self) = @_;
    my $code = $xsub->($self);
    Net::Swirl::CurlEasy::Exception::CurlCode::throw($code) if $code;
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
    Net::Swirl::CurlEasy::Exception::Swirl::throw('buffer-ref') unless is_ref $buf;
    $$buf = '' unless defined $$buf;
    Net::Swirl::CurlEasy::Exception::Swirl::throw('buffer-ref') unless is_scalarref $buf;

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
      Net::Swirl::CurlEasy::Exception::CurlCode::throw($code);
    }

    FFI::Platypus::Buffer::set_used_length($$buf, $out_size);

    return $out_size;
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
    Net::Swirl::CurlEasy::Exception::Swirl::throw('buffer-ref') unless is_scalarref $buf;

    my ($ptr,$size_in) = FFI::Platypus::Buffer::scalar_to_buffer($$buf);

    my $code = $xsub->($self, $ptr+$offset, $size_in-$offset, \my $out_size);
    if($code != 0)
    {
      return undef if $code == 81;
      Net::Swirl::CurlEasy::Exception::CurlCode::throw($code);
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

=head3 maxredirs

 $curl->setopt( maxredirs => $max );

Sets the maximum number of redirects.  Setting the limit to C<0> will force
L<Net::Swirl::CurlEasy> refuse any redirect.  Set to C<-1> for an infinite
number of redirects.

( L<CURLOPT_MAXREDIRS|https://curl.se/libcurl/c/CURLOPT_MAXREDIRS.html> )

=head3 url

 $curl->setopt( url => $url );

The URL to work with.  This is the only required option.

( L<CURLOPT_URL|https://curl.se/libcurl/c/CURLOPT_URL.html> )

=head3 writedata

 $curl->setopt( writedata => $value );

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

=cut

  $ffi->attach( [setopt => '_setopt_stringpoint'  ] => ['CURL','enum'] => ['string'] => 'enum' );
  $ffi->attach( [setopt => '_setopt_long'         ] => ['CURL','enum'] => ['long']   => 'enum' );
  $ffi->attach( [setopt => '_setopt_off_t'        ] => ['CURL','enum'] => ['off_t']  => 'enum' );

  $ffi->attach( [setopt => '_setopt_slistpoint'   ] => ['CURL','enum'] => ['opaque'] => 'enum' => sub ($xsub, $self, $key_id, $items) {
    my $slist = Net::Swirl::CurlEasy->new($items->@*);
    $xsub->($self, $key_id, $slist->ptr);
  });

  $ffi->attach( [setopt => '_setopt_writefunction_cb'] => ['CURL','enum'] => ['(opaque,size_t,size_t,opaque)->size_t'] => 'enum' => sub ($xsub, $self, $key_id, $cb) {
    my $closure = $keep{$$self}->{$key_id} = $ffi->closure(sub ($ptr, $size, $nm, $) {
      window my $data, $ptr, $size*$nm;
      local $@ = '';
      eval {
        # 10001 = WRITEDATA
        $cb->($self, $data, $keep{$$self}->{10001})
      };
      # TODO: there should also be a callback to handle this
      warn $@ if $@;
      return 0 if $@;
      return $size*$nm;
    });
    $xsub->($self, $key_id, $closure);
  });

  require Net::Swirl::CurlEasy::Options unless $Net::Swirl::CurlEasy::no_gen;

  our %opt = (%opt,
    writefunction => [ 20011, \&_setopt_writefunction_cb ],
    writedata     => [ 10001, sub ($self, $key_id, $value) {
      $keep{$$self}->{$key_id} = $value;
      0;
    }],
  );

  sub setopt ($self, $key, $value)
  {
    Net::Swirl::CurlEasy::Exception::CurlCode::throw(48) unless defined $opt{$key};
    my($key_id, $xsub) = $opt{$key}->@*;
    my $code = $xsub->($self, $key_id, $value);
    Net::Swirl::CurlEasy::Exception::CurlCode::throw($code) if $code;
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
    my($in_ptr, $in_size) = scalar_to_buffer $in;
    my $out_ptr = $xsub->($self, $in_ptr, $in_size, \my $out_size);
    my $out = buffer_to_scalar $out_ptr, $out_size;
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
    Net::Swirl::CurlEasy::Exception::CurlCode::throw($code) if $code;
    $self;
  });

}

1;

=head1 EXCEPTIONS

In general methods should throw an exception object on failure.  In some cases L<Net::Swirl::CurlEasy>
calls modules that may throw a string exception.

Here is how you might catch exceptions using the new C<try> and C<isa> features:

 use experimental qw( try isa );
 
 try {
   Net::Swirl::CurlEasy
     ->new
     ->setopt( url => 'https://alienfile.org' )
     ->perform;
 } catch ($e) {
   if($e isa Net::Swirl::CurlEasy::Exception::CurlCode) {
 
    my $code = $e->code;  # integer code
 
   } elsif($e isa Net::Swirl::CurlEasy::Exception::CurlCod) {
 
    if($e->code eq 'create-failed') {
      # the constructor failed to create an instance
      # rare
    } elsif($e->code eq 'internal') {
      # internal Swirl error
      # hopefully also rare
    }
 
   } else {
     # some exception not coming directly from libcurl or Swirl
   }
 }

=head2 Net::Swirl::CurlEasy::Exception

This is the base class for L<Net::Swirl::CurlEasy> exceptions.  It is an abstract class
in that you should only see sub class exceptions.

=over 4

=item as_string

A human readable diagnostic explaining the error, with the location from where the
exception was thrown.  This looks like what a normal C<warn> or C<die> diagnostic
would produce.  This is also what you get if you attempt to stringify the exception
(C<"$exception">).

=item filename

The file in your code from which the exception was thrown.

=item line

The line number in your code from which the exception was thrown.

=item package

The package in your code from which the exception was thrown.

=item strerror

A human readable diagnostic explaining the error.

=back

=head2 Net::Swirl::CurlEasy::Exception::CurlCode

This is an exception that originated from C<libcurl> and has a corresponding C<CURLcode>.
It covers that vast majority of exceptions that you will see from this module.
It has these additional properties:

=over 4

=item code

This is the integer C<libcurl> code.  The full list of possible codes can be found here:
L<https://curl.se/libcurl/c/libcurl-errors.html>.  Note that typically an exception for
C<CURLE_OK> is not normally thrown so you should not see that value in an exception.

=back

=head2 Net::Swirl::CurlEasy::Exception::Swirl

This is an exception that originates in L<Net::Swirl::CurlEasy> itself, or from
C<libcurl> in a way that no C<CURLcode> is provided.

=over 4

=item code

This is the string code that classifies the type of exception.  You can check against
these values as they should not change, where as the human readable C<strerror> may
change in the future without notice.  Possible values include:

=over 4

=item C<buffer-ref>

The L<send|/send> and L<recv|/recv> methods take a reference to a string scalar, and
you passed in something else.

=item C<create-failed>

C<libcurl> was unable to create an instance.

=item C<internal>

An internal error.

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

=head2 Implement Protocols With send and recv

=head3 source

# EXAMPLE: examples/connect-only.pl

=head3 execute

 $ perl -Ilib examples/connect-only.pl
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

=head1 SEE ALSO

=over 4

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
