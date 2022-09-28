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

  sub _default_writefunction ($, $data, $fh) {
    print $fh $data;
  }

  $ffi->attach( [init => 'new'] => [] => 'opaque' => sub {
    my($xsub, $class) = @_;
    my $ptr = $xsub->();
    croak "unable to create curl easy instance" unless $ptr;
    my $self = bless \$ptr, $class;
    $self->setopt( writefunction => \&_default_writefunction );
    $self->setopt( writedata     => \*STDOUT );
    $self;
  });

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

=head2 getinfo

 my $value = $curl->getinfo($name);

Request internal information from the curl session with this function.  This will
throw L<Net::Swirl::CurlEasy::Exception|/Net::Swirl::CurlEasy::Exception> in the
event of an error.

( L<curl_easy_getinfo|https://curl.se/libcurl/c/curl_easy_getinfo.html> )

What follows is a partial list of supported information.  The full list of
available information is listed in L<Net::Swirl::CurlEasy::Info>.

=head3 scheme

 my $scheme = $curl->getinfo('scheme');

URL scheme used for the most recent connection done.

( L<CURLINFO_SCHEME|https://curl.se/libcurl/c/CURLINFO_SCHEME.html> )

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
on error.

( L<curl_easy_setopt|https://curl.se/libcurl/c/curl_easy_setopt.html> )

What follows is a partial list of supported options.  The full list of
options can be found in L<Net::Swirl::CurlEasy::Options>.

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
