package Net::Curl::Easy::FFI {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use Carp qw( croak );
  use FFI::Platypus::Buffer qw( window );
  use Net::Curl::Easy::FFI::Lib;

# ABSTRACT: Perl interface to curl's "easy" interface

=head1 SYNOPSIS

 use Net::Curl::Easy::FFI;
 
 my $curl = Net::Curl::Easy::FFI->new;
 $curl->setopt( url => "https://metacpan.org" );
 $curl->perform;

=head1 DESCRIPTION

This is an experimental interface to curl's "easy" API interface.
It uses L<Alien::curl> to provide native TLS support on Windows and macOS,
and L<FFI::Platypus> to simplify development.

=cut

  my $ffi;

  BEGIN {
    $ffi = FFI::Platypus->new(
      api => 2,
      lib => [Net::Curl::Easy::FFI::Lib->lib],
    );
    $ffi->bundle;
  }

  $ffi->mangler(sub ($name) { "curl_easy_$name" });
  $ffi->type( 'object(Net::Curl::Easy::FFI)' => 'CURL' );

  package Net::Curl::Easy::FFI::Exception {

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

 my $curl = Net::Curl::Easy::FFI->new;

This creates a new instance of this class.  Throws a string exception
in the unlikely event that the instance cannot be created.

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

Methods without a return value specified here return the L<Net::Curl::Easy::FFI> instance
so that they can be chained.

=head2 perform

 $curl->perform;

Perform the curl request.  Throws a L<Net::Curl::Easy::FFI::Exception> on
error.

=cut

  $ffi->attach( perform => ['CURL'] => 'enum' => sub {
    my($xsub, $self) = @_;
    my $code = $xsub->($self);
    Net::Curl::Easy::FFI::Exception::throw($code) if $code;
    $self;
  });

=head2 setopt

 $curl->setopt( $option => $parameter );

Sets the given curl option.  Throws a L<Net::Curl::Easy::FFI::Exception>
on error.  Supported options include:

=over 4

=item url (CURLOPT_URL)

 $curl->setopt( url => $url );

The URL to work with.

=item writefunction (CURLOPT_WRITEFUNCTION)

 my $code = $curl->setopt( writefunction => sub ($data) { ... } );

The write function will be called for each block of data returned.
The data is passed as a single scalar argument (the scalar uses
L<FFI::Platypus::Buffer/window> to efficiently expose the data
without having to copy it).  If an exception is thrown, then an
error will be passed back to curl (in the form of zero bytes
handled).

=back

=cut

  $ffi->attach( [setopt => '_setopt_string'  ] => ['CURL','enum'] => ['string'] => 'enum' );

  $ffi->attach( [setopt => '_setopt_write_cb'] => ['CURL','enum'] => ['(opaque,size_t,size_t,opaque)->size_t'] => 'enum' => sub {
    my($xsub, $self, $key_id, $cb) = @_;
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

  my %opt = (
    url           => [CURLOPT_URL,           \&_setopt_string,   0],
    writefunction => [CURLOPT_WRITEFUNCTION, \&_setopt_write_cb, 1],
  );

  sub setopt ($self, $key, $value)
  {
    my($key_id, $xsub,$cb) = $opt{$key}->@*;
    # TODO: should throw an object
    croak "unknown option $key" unless defined $key_id;
    my $code = $xsub->($self, $key_id, $value);
    Net::Curl::Easy::FFI::Exception::throw($code) if $code;
    $self;
  }

}

1;

=head1 SEE ALSO

=over 4

=item L<Net::Curl::Easy>

=item L<Alien::curl>

=item L<FFI::Platypus>

=back

=cut
