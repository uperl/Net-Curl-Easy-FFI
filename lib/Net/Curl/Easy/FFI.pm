package Net::Curl::Easy::FFI {

  use warnings;
  use 5.020;
  use experimental qw( signatures postderef );
  use FFI::Platypus 2.00;
  use Alien::curl;
  use Carp qw( croak );
  use FFI::Platypus::Buffer qw( window );

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
      lib => [Alien::curl->dynamic_libs],
    );
    $ffi->bundle;
  }

  $ffi->mangler(sub ($name) { "curl_easy_$name" });
  $ffi->type( 'object(Net::Curl::Easy::FFI)' => 'CURL' );

=head1 CONSTRUCTOR

=head2 new

 my $curl = Net::Curl::Easy::FFI->new;

This creates a new instance of this class.  Throws an exception
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

=head2 perform

 my $code = $curl->perform;

Perform the curl request.

=cut

  $ffi->attach( perform => ['CURL'] => 'enum' );

=head2 setopt

 my $code = $curl->setopt( $option => $parameter );

Sets the given curl option.  Supported options include:

=over 4

=item url (CURLOPT_URL)

 my $code = $curl->setopt( url => $url );

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
    croak "unknown option $key" unless defined $key_id;
    $xsub->($self, $key_id, $value);
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
