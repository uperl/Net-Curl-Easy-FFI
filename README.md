# Net::Curl::Easy::FFI ![static](https://github.com/uperl/Net-Curl-Easy-FFI/workflows/static/badge.svg) ![linux](https://github.com/uperl/Net-Curl-Easy-FFI/workflows/linux/badge.svg)

Perl interface to curl's "easy" interface

# SYNOPSIS

```perl
use Net::Curl::Easy::FFI;

my $curl = Net::Curl::Easy::FFI->new;
$curl->setopt( url => "https://metacpan.org" );
$curl->perform;
```

# DESCRIPTION

This is an experimental interface to curl's "easy" API interface.
It uses [Alien::curl](https://metacpan.org/pod/Alien::curl) to provide native TLS support on Windows and macOS,
and [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) to simplify development.

# CONSTRUCTOR

## new

```perl
my $curl = Net::Curl::Easy::FFI->new;
```

This creates a new instance of this class.  Throws an exception
in the unlikely event that the instance cannot be created.

# METHODS

## perform

```perl
my $code = $curl->perform;
```

Perform the curl request.

## setopt

```perl
my $code = $curl->setopt( $option => $parameter );
```

Sets the given curl option.  Supported options include:

- url (CURLOPT\_URL)

    ```perl
    my $code = $curl->setopt( url => $url );
    ```

    The URL to work with.

- writefunction (CURLOPT\_WRITEFUNCTION)

    ```perl
    my $code = $curl->setopt( writefunction => sub ($data) { ... } );
    ```

    The write function will be called for each block of data returned.
    The data is passed as a single scalar argument (the scalar uses
    ["window" in FFI::Platypus::Buffer](https://metacpan.org/pod/FFI::Platypus::Buffer#window) to efficiently expose the data
    without having to copy it).  If an exception is thrown, then an
    error will be passed back to curl (in the form of zero bytes
    handled).

# SEE ALSO

- [Net::Curl::Easy](https://metacpan.org/pod/Net::Curl::Easy)
- [Alien::curl](https://metacpan.org/pod/Alien::curl)
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
