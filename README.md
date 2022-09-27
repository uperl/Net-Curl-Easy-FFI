# Net::Swirl::CurlEasy ![static](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/static/badge.svg) ![linux](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/linux/badge.svg) ![ref](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/ref/badge.svg)

Perl interface to curl's "easy" interface

# SYNOPSIS

```perl
use Net::Swirl::CurlEasy;

Net::Swirl::CurlEasy
  ->new
  ->setopt( url => "https://metacpan.org" );
  ->perform;
```

# DESCRIPTION

This is an experimental interface to curl's "easy" API interface.
It uses [Alien::curl](https://metacpan.org/pod/Alien::curl) to provide native TLS support on Windows and macOS,
and [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) to simplify development.

This module uses the `Net::Swirl` prefix as swirl is a synonym I liked
that google suggested for "curl".  I felt the `Net::Curl::` namespace was
already a little crowded, and I plan on adding additional modules in this
namespace for other parts of the `libcurl` API.

# CONSTRUCTOR

## new

```perl
my $curl = Net::Swirl::CurlEasy->new;
```

This creates a new instance of this class.  Throws a string exception
in the unlikely event that the instance cannot be created.

# METHODS

Methods without a return value specified here return the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance
so that they can be chained.

## perform

```
$curl->perform;
```

Perform the curl request.  Throws a [Net::Swirl::CurlEasy::Exception](https://metacpan.org/pod/Net::Swirl::CurlEasy::Exception) on
error.

[curl\_easy\_perform](https://curl.se/libcurl/c/curl_easy_perform.html)

## setopt

```perl
$curl->setopt( $option => $parameter );
```

Sets the given curl option.  Throws a [Net::Swirl::CurlEasy::Exception](https://metacpan.org/pod/Net::Swirl::CurlEasy::Exception)
on error.  Supported options include:

- url

    ```perl
    $curl->setopt( url => $url );
    ```

    The URL to work with.

    [CURLOPT\_URL](https://curl.se/libcurl/c/CURLOPT_URL.html)

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

    [CURLOPT\_URL](https://curl.se/libcurl/c/CURLOPT_WRITEFUNCTION.html)

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
