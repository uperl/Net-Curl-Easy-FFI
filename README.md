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

This is an alternative interface to curl's "easy" API interface.
It uses [Alien::curl](https://metacpan.org/pod/Alien::curl) to provide native TLS support on Windows and macOS,
and [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus) to simplify development.

This module uses the `Net::Swirl` prefix as swirl is a synonym I liked
that google suggested for "curl".  I felt the `Net::Curl::` namespace was
already a little crowded, and I plan on adding additional modules in this
namespace for other parts of the `libcurl` API.

If you are just beginning you should start out with the [example section](#examples)
below.

# CONSTRUCTOR

## new

```perl
my $curl = Net::Swirl::CurlEasy->new;
```

This creates a new instance of this class.  Throws a string exception
in the unlikely event that the instance cannot be created.

( [curl\_easy\_init](https://curl.se/libcurl/c/curl_easy_init.html) )

# METHODS

Methods without a return value specified here return the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance
so that they can be chained.

## getinfo

```perl
my $value = $curl->getinfo($name);
```

Request internal information from the curl session with this function.  This will
throw [Net::Swirl::CurlEasy::Exception](#net-swirl-curleasy-exception) in the
event of an error.

( [curl\_easy\_getinfo](https://curl.se/libcurl/c/curl_easy_getinfo.html) )

- scheme

    URL scheme used for the most recent connection done.

    ( [CURLINFO\_SCHEME](https://curl.se/libcurl/c/CURLINFO_SCHEME.html) )

## perform

```
$curl->perform;
```

Perform the curl request.  Throws a
[Net::Swirl::CurlEasy::Exception](#net-swirl-curleasy-exception) on error.

( [curl\_easy\_perform](https://curl.se/libcurl/c/curl_easy_perform.html) )

## setopt

```perl
$curl->setopt( $option => $parameter );
```

Sets the given curl option.  Throws a
[Net::Swirl::CurlEasy::Exception](#net-swirl-curleasy-exception)
on error.  Supported options include:

( [curl\_easy\_setopt](https://curl.se/libcurl/c/curl_easy_setopt.html) )

- url

    ```perl
    $curl->setopt( url => $url );
    ```

    The URL to work with.

    ( [CURLOPT\_URL](https://curl.se/libcurl/c/CURLOPT_URL.html) )

- writefunction

    ```perl
    my $code = $curl->setopt( writefunction => sub ($curl, $content, $writedata) {
      ...
    });
    ```

    The writefunction callback will be called for each block of content
    returned.  The content is passed as the second argument (the scalar uses
    ["window" in FFI::Platypus::Buffer](https://metacpan.org/pod/FFI::Platypus::Buffer#window) to efficiently expose the data
    without having to copy it).  If an exception is thrown, then an
    error will be passed back to curl (in the form of zero bytes
    handled).

    The callback also gets passed the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance as
    its first argument, and the `writedata` option as its third argument.

    ( [CURLOPT\_WRITEFUNCTION](https://curl.se/libcurl/c/CURLOPT_WRITEFUNCTION.html) )

# EXCEPTIONS

In general methods should throw an exception object on failure.  In some cases if [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy)
calls modules that may throw a string exception.

## Net::Swirl::CurlEasy::Exception

This is the normal exception class used by [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy).  It has these properties:

- as\_string

    A human readable diagnostic explaining the error, with the location from where the
    exception was thrown.  This looks like what a normal `warn` or `die` diagnostic
    would produce.  This is also what you get if you attempt to stringify the exception
    (`"$exception"`).

- code

    This is the integer `libcurl` code.  The full list of possible codes can be found here:
    [https://curl.se/libcurl/c/libcurl-errors.html](https://curl.se/libcurl/c/libcurl-errors.html).  Note that typically an exception for
    `CURLE_OK` is not normally thrown so you should not see that value in an exception.

- filename

    The file in your code from which the exception was thrown.

- line

    The line number in your code from which the exception was thrown.

- package

    The package in your code from which the exception was thrown.

- strerror

    A human readable diagnostic explaining the error.

# EXAMPLES

All of the examples are provided in the `examples` subdirectory of this distribution.

These examples will work against this very simple PSGI app that you can run locally.

```perl
use warnings;
use 5.020;
use experimental qw( signatures );

package Plack::App::HelloWorld {

  use parent qw( Plack::Component );

  sub call ($self, $env) {
    my $path = $env->{PATH_INFO} || '/';
    return $self->return_404 if $path =~ /\0/;

    if($path eq '/hello-world') {
      return [200, ['Content-Type' => 'text/plain'], ["Hello World!\n"]];
    }

    if($path eq '/') {
      return [301, ['Location' => '/hello-world'], ['']];
    }

    return $self->return_404;
  }

  sub return_404 ($self) {
    return [404, ['Content-Type' => 'text/plain'], ['not found']];
  }
}

Plack::App::HelloWorld->new->to_app;
```

You can start it up by running `plackup examples/server.psgi` and it will listen to port 5000
by default.  (If you are running on a recent version of macOS that also runs "AirPlay Receiver"
on that port, you can either change the port number and by passing `-p 5001` to plackup, and
in each of these examples or by stopping "AirPlay Receiver" in the sharing dialog of the
control panel).

## Simple GET

### source

```perl
use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000')
     ->setopt(followlocation => 1)  # equivalent to curl -L
     ->perform;
```

### execute

```
$ perl examples/simple.pl 
Hello World!
```

### notes

This is a very simple GET.  If any method fails it will throw an exception, and methods that
do not otherwise return a useful value return the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) object so they can
be chained like this.

The basic flow of most requests will work like this, once [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance is
created, you can set what options you want using [setopt](#setopt), and then call
[perform](#perform) to make the actual request.  The only **required** option is `url`.  We
also set `followlocation` to follow any redirects, since our server PSGI redirects `/` to
`/hello-world`.  If you did not set this option, then you would get the 301 response
instead.  If you are used to using the `curl` command line interface, this is equivalent
to its `-L` option.

By default curl writes the body of the response to STDOUT, which is why we see it printed
when the example is run.

## Capture Response Body With writedata

### source

```perl
use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my $content;
open my $wd, '>', \$content;

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->setopt(writedata => $wd)
     ->perform;

# the server includes a new line
chomp $content;

say "the server said '$content'";
```

### execute

```
$ perl examples/writedata.pl 
the server said 'Hello World!'
```

### notes

Normally when using `libcurl` programmatically you don't want to print the response body to
`STDOUT`, you want to capture it in a variable to store or manipulate as appropriate.  The
`writedata` option allows you to do this.  The default implementation treats this option as
a file handle, so you can use any Perl object that supports the file handle interface.  Here
we use a handle that is redirecting to a scalar variable.  The reason the first example sends
output to `STDOUT` is that `STDOUT` is the default for this option!

## Capture Response Body With writefunction

### source 

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my $content = '';

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->setopt(writefunction => sub ($, $data, $) {
       $content .= $data;
     })
     ->perform;

# the server includes a new line
chomp $content;

say "the server said '$content'";
```

### execute

```
$ perl examples/writefunction.pl
the server said 'Hello World!'
```

### notes

You might want to route the data into a database or other store in chunks so that you do not
have to keep the entire response body in memory at one time.  In this example we use the
`writefunction` option to define a callback function that will be called for each chunk
of the response.  The size of the chunks can vary depending on `libcurl`.  You could have a
large chunk or even a chunk of zero bytes!

You may have noticed that the `writefunction` callback takes two arguments, the second of
which we do not use.  This is the `writedata` option.  As mentioned in the previous example,
the default `writefunction` callback treats this as a file handle, but it could be any
Perl data structure.

The default `writefunction` callback looks like this:

```perl
$curl->setopt( writefunction => sub ($, $data, $fh) {
  print $fh $data;
});
```

# SEE ALSO

- [Net::Curl::Easy](https://metacpan.org/pod/Net::Curl::Easy)
- [Alien::curl](https://metacpan.org/pod/Alien::curl)
- [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus)
- [https://curl.se](https://curl.se)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
