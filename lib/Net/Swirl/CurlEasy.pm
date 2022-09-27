package Net::Swirl::CurlEasy {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use Carp qw( croak );
  use FFI::Platypus::Buffer qw( window );
  use Net::Swirl::CurlEasy::FFI;

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
    $ffi->bundle;
  }

  $ffi->type( 'object(Net::Swirl::CurlEasy)' => 'CURL' );

  $ffi->mangler(sub ($name) { "curl_slist_$name" });

  package Net::Swirl::CurlEasy::Slist {

    sub new ($, @items) {
      my $ptr;
      my $self = bless \$ptr, __PACKAGE__;
      $self->append($_) for @items;
    }

    sub ptr ($self) { $$self }

    $ffi->attach( append => ['opaque', 'string'] => 'opaque' => sub ($xsub, $self, $value) {
      $$self = $xsub->($$self, $value);
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

=head2 perform

 $curl->perform;

Perform the curl request.  Throws a L<Net::Swirl::CurlEasy::Exception> on
error.

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

Sets the given curl option.  Throws a L<Net::Swirl::CurlEasy::Exception>
on error.  Supported options include:

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

  $ffi->attach( [setopt => '_setopt_slistpoint'   ] => ['CURL','enum'] => ['opaque'] => 'enum' => sub ($xsub, $self, $key_id, @items) {
    my $slist = Net::Swirl::CurlEasy->new(@items);
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
    writefunction => [CURLOPT_WRITEFUNCTION, \&_setopt_write_cb,   ],
  );

  sub setopt ($self, $key, $value)
  {
    my($key_id, $xsub,$cb) = $opt{$key}->@*;
    # TODO: should throw an object
    croak "unknown option $key" unless defined $key_id;
    my $code = $xsub->($self, $key_id, $value);
    Net::Swirl::CurlEasy::Exception::throw($code) if $code;
    $self;
  }

}

1;

=head1 SEE ALSO

=over 4

=item L<Net::Curl::Easy>

=item L<Alien::curl>

=item L<FFI::Platypus>

=item L<https://curl.se>

=back

=cut
