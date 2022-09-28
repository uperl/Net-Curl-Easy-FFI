package Net::Swirl::CurlEasy {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use Carp qw( croak );
  use FFI::Platypus::Buffer qw( window );
  use Net::Swirl::CurlEasy::FFI;
  use FFI::C;

# ABSTRACT: Perl interface to curl's "easy" interface

=head1 SYNOPSIS

 use Net::Swirl::CurlEasy;
 
 Net::Swirl::CurlEasy
   ->new
   ->setopt( url => "https://metacpan.org" );
   ->perform;

=head1 DESCRIPTION

This is an experimental interface to curl's "easy" API interface.
It uses L<Alien::curl> to provide native TLS support on Windows and macOS,
and L<FFI::Platypus> to simplify development.

This module uses the C<Net::Swirl> prefix as swirl is a synonym I liked
that google suggested for "curl".  I felt the C<Net::Curl::> namespace was
already a little crowded, and I plan on adding additional modules in this
namespace for other parts of the C<libcurl> API.

=cut

  my $ffi;

  BEGIN {
    $ffi = FFI::Platypus->new(
      api => 2,
      lib => [Net::Swirl::CurlEasy::FFI->lib],
    );
  }

  $ffi->type( 'object(Net::Swirl::CurlEasy)' => 'CURL' );

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

    sub throw ($code) {
      my($package, $filename, $line) = caller(1);
      die bless {
        code     => $code,
        package  => $package,
        filename => $filename,
        line     => $line,
      }, __PACKAGE__;
    }

    sub code     ($self) { $self->{code}     }
    sub package  ($self) { $self->{package}  }
    sub filename ($self) { $self->{filename} }
    sub line     ($self) { $self->{line}     }

    $ffi->attach( strerror => ['enum'] => 'string' => sub ($xsub, $self) {
      $xsub->($self->{code});
    });

    sub as_string ($self)
    {
      sprintf "%s at %s line %s.", $self->strerror, $self->filename, $self->line;
    }

  }

=head1 CONSTRUCTOR

=head2 new

 my $curl = Net::Swirl::CurlEasy->new;

This creates a new instance of this class.  Throws a string exception
in the unlikely event that the instance cannot be created.

( L<curl_easy_init|https://curl.se/libcurl/c/curl_easy_init.html> )

=cut

  $ffi->attach( [init => 'new'] => [] => 'opaque' => sub {
    my($xsub, $class) = @_;
    my $ptr = $xsub->();
    croak "unable to create curl easy instance" unless $ptr;
    bless \$ptr, $class;
  });

  our %keep;

  $ffi->attach( [cleanup => 'DESTROY'] => ['CURL'] => 'void' => sub {
    my($xsub, $self) = @_;
    delete $keep{$$self};
    $xsub->($self);
  });

=head1 METHODS

Methods without a return value specified here return the L<Net::Swirl::CurlEasy> instance
so that they can be chained.

=head2 getinfo

 my $value = $curl->getinfo($name);

Request internal information from the curl session with this function.  This will
throw L<Net::Swirl::CurlEasy::Exception|/Net::Swirl::CurlEasy::Exception> in the
event of an error.

( L<curl_easy_getinfo|https://curl.se/libcurl/c/curl_easy_getinfo.html> )

=over 4

=item scheme

URL scheme used for the most recent connection done.

( L<CURLINFO_SCHEME|https://curl.se/libcurl/c/CURLINFO_SCHEME.html> )

=back

=cut

  $ffi->attach( [getinfo => '_getinfo_string'] => ['CURL','enum'] => ['string*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_double'] => ['CURL','enum'] => ['double*'] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_long'  ] => ['CURL','enum'] => ['long*'  ] => 'enum' );
  $ffi->attach( [getinfo => '_getinfo_off_t' ] => ['CURL','enum'] => ['off_t*' ] => 'enum' );

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
  );

  sub getinfo ($self, $key)
  {
    my($key_id, $xsub) = $info{$key}->@*;
    # TODO: should thow an object
    croak "unknown info $key" unless defined $key_id;
    my $code = $xsub->($self, $key_id, \my $value);
    Net::Swirl::CurlEasy::Exception::throw($code) if $code;
    return $value;
  }

=head2 perform

 $curl->perform;

Perform the curl request.  Throws a
L<Net::Swirl::CurlEasy::Exception|/Net::Swirl::CurlEasy::Exception> on error.

( L<curl_easy_perform|https://curl.se/libcurl/c/curl_easy_perform.html> )

=cut

  $ffi->attach( perform => ['CURL'] => 'enum' => sub {
    my($xsub, $self) = @_;
    my $code = $xsub->($self);
    Net::Swirl::CurlEasy::Exception::throw($code) if $code;
    $self;
  });

=head2 setopt

 $curl->setopt( $option => $parameter );

Sets the given curl option.  Throws a
L<Net::Swirl::CurlEasy::Exception|/Net::Swirl::CurlEasy::Exception>
on error.  Supported options include:

( L<curl_easy_setopt|https://curl.se/libcurl/c/curl_easy_setopt.html> )

=over 4

=item url

 $curl->setopt( url => $url );

The URL to work with.

( L<CURLOPT_URL|https://curl.se/libcurl/c/CURLOPT_URL.html> )

=item writefunction

 my $code = $curl->setopt( writefunction => sub ($data) { ... } );

The write function will be called for each block of data returned.
The data is passed as a single scalar argument (the scalar uses
L<FFI::Platypus::Buffer/window> to efficiently expose the data
without having to copy it).  If an exception is thrown, then an
error will be passed back to curl (in the form of zero bytes
handled).

( L<CURLOPT_WRITEFUNCTION|https://curl.se/libcurl/c/CURLOPT_WRITEFUNCTION.html> )

=back

=cut

  $ffi->attach( [setopt => '_setopt_stringpoint'  ] => ['CURL','enum'] => ['string'] => 'enum' );
  $ffi->attach( [setopt => '_setopt_long'         ] => ['CURL','enum'] => ['long']   => 'enum' );
  $ffi->attach( [setopt => '_setopt_off_t'        ] => ['CURL','enum'] => ['off_t']  => 'enum' );

  $ffi->attach( [setopt => '_setopt_slistpoint'   ] => ['CURL','enum'] => ['opaque'] => 'enum' => sub ($xsub, $self, $key_id, $items) {
    my $slist = Net::Swirl::CurlEasy->new($items->@*);
    $xsub->($self, $key_id, $slist->ptr);
  });

  $ffi->attach( [setopt => '_setopt_write_cb'] => ['CURL','enum'] => ['(opaque,size_t,size_t,opaque)->size_t'] => 'enum' => sub ($xsub, $self, $key_id, $cb) {
    my $closure = $keep{$$self}->{$key_id} = $ffi->closure(sub ($ptr, $size, $nm, $) {
      window my $data, $ptr, $size*$nm;
      local $@ = '';
      eval {
        $cb->($data)
      };
      # TODO: should we warn?  make a callback?
      return 0 if $@;
      return $size*$nm;
    });
    $xsub->($self, $key_id, $closure);
  });

  require Net::Swirl::CurlEasy::Options unless $Net::Swirl::CurlEasy::no_gen;

  our %opt = (%opt,
    writefunction => [20011, \&_setopt_write_cb ],
  );

  sub setopt ($self, $key, $value)
  {
    my($key_id, $xsub) = $opt{$key}->@*;
    # TODO: should throw an object
    croak "unknown option $key" unless defined $key_id;
    my $code = $xsub->($self, $key_id, $value);
    Net::Swirl::CurlEasy::Exception::throw($code) if $code;
    $self;
  }

}

1;

=head1 EXCEPTIONS

In general methods should throw an exception object on failure.  In some cases if L<Net::Swirl::CurlEasy>
calls modules that may throw a string exception.

=head2 Net::Swirl::CurlEasy::Exception

This is the normal exception class used by L<Net::Swirl::CurlEasy>.  It has these properties:

=over 4

=item as_string

A human readable diagnostic explaining the error, with the location from where the
exception was thrown.  This looks like what a normal C<warn> or C<die> diagnostic
would produce.  This is also what you get if you attempt to stringify the exception
(C<"$exception">).

=item code

This is the integer C<libcurl> code.  The full list of possible codes can be found here:
L<https://curl.se/libcurl/c/libcurl-errors.html>.  Note that typically an exception for
C<CURLE_OK> is not normally thrown so you should not see that value in an exception.

=item filename

The file in your code from which the exception was thrown.

=item line

The line number in your code from which the exception was thrown.

=item package

The package in your code from which the exception was thrown.

=item strerror

A human readable diagnostic explaining the error.

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
L<perform|/perform> to make the actual request.  The only B<required> option is C<url>.  We
also set C<followlocation> to follow any redirects, since our server PSGI redirects C</> to
C</hello-world>.  If you did not set this option, then you would get the 301 response
instead.  If you are used to using the C<curl> command line interface, this is equivalent
to its C<-L> option.

By default curl writes the body of the response to STDOUT, which is why we see it printed
when the example is run.

=head1 SEE ALSO

=over 4

=item L<Net::Curl::Easy>

=item L<Alien::curl>

=item L<FFI::Platypus>

=item L<https://curl.se>

=back

=cut
