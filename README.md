# Net::Swirl::CurlEasy ![static](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/static/badge.svg) ![linux](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/linux/badge.svg) ![ref](https://github.com/uperl/Net-Swirl-CurlEasy/workflows/ref/badge.svg)

Perl bindings to curl's "easy" interface

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

This creates a new instance of this class.  The constructor can throw either
[Net::Swirl::CurlEasy::Exception::Swirl](#net-swirl-curleasy-exception-swirl)
or
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
on failure.

( [curl\_easy\_init](https://curl.se/libcurl/c/curl_easy_init.html) )

# METHODS

Methods without a return value specified here return the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance
so that they can be chained.

## clone

```perl
my $curl2 = $curl->clone;
```

This method will return a new [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance, a duplicate, using all the
options previously set in the original instance. Both instances can subsequently be used
independently.

The new instance will not inherit any state information, no connections, no SSL sessions
and no cookies. It also will not inherit any share object states or options (it will
be made as if CURLOPT\_SHARE was set to `undef`).

In multi-threaded programs, this function must be called in a synchronous way, the
original instance may not be in use when cloned.

[Net::Swirl::CurlEasy::Exception::Swirl](#net-swirl-curleasy-exception-swirl)
or
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
on failure.

( [curl\_easy\_duphandle](https://curl.se/libcurl/c/curl_easy_duphandle.html) )

## escape

```perl
my $escaped = $curl->escape($unescaped);
```

This function converts the given input string to a URL encoded string and returns that
as a new allocated string. All input characters that are not a-z, A-Z, 0-9,  '-', '.',
'\_' or '~' are converted to their "URL escaped" version (`%NN` where NN is a two-digit
hexadecimal number).

( [curl\_easy\_escape](https://curl.se/libcurl/c/curl_easy_escape.html) )

## getinfo

```perl
my $value = $curl->getinfo($name);
```

Request internal information from the curl session with this function.  This will
throw
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
in the event of an error.

( [curl\_easy\_getinfo](https://curl.se/libcurl/c/curl_easy_getinfo.html) )

What follows is a partial list of supported information.  The full list of
available information is listed in [Net::Swirl::CurlEasy::Info](https://metacpan.org/pod/Net::Swirl::CurlEasy::Info).

### scheme

```perl
my $scheme = $curl->getinfo('scheme');
```

URL scheme used for the most recent connection done.

( [CURLINFO\_SCHEME](https://curl.se/libcurl/c/CURLINFO_SCHEME.html) )

## perform

```
$curl->perform;
```

Perform the curl request.  Throws a
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode) on error.

( [curl\_easy\_perform](https://curl.se/libcurl/c/curl_easy_perform.html) )

## setopt

```perl
$curl->setopt( $option => $parameter );
```

Sets the given curl option.  Throws a
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
on error.

( [curl\_easy\_setopt](https://curl.se/libcurl/c/curl_easy_setopt.html) )

What follows is a partial list of supported options.  The full list of
options can be found in [Net::Swirl::CurlEasy::Options](https://metacpan.org/pod/Net::Swirl::CurlEasy::Options).

### followlocation

```perl
$curl->setopt( followlocation => $bool );
```

Set this to 1 (the default is 0) to follow redirect responses.
The maximum number of redirects can be controlled by
[maxredirs](#maxredirs).

( [CURLOPT\_FOLLOWLOCATION](https://curl.se/libcurl/c/CURLOPT_FOLLOWLOCATION.html) )

### maxredirs

```perl
$curl->setopt( maxredirs => $max );
```

Sets the maximum number of redirects.  Setting the limit to `0` will force
[Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) refuse any redirect.  Set to `-1` for an infinite
number of redirects.

( [CURLOPT\_MAXREDIRS](https://curl.se/libcurl/c/CURLOPT_MAXREDIRS.html) )

### url

```perl
$curl->setopt( url => $url );
```

The URL to work with.  This is the only required option.

( [CURLOPT\_URL](https://curl.se/libcurl/c/CURLOPT_URL.html) )

### writedata

```perl
$curl->setopt( writedata => $value );
```

The `writedata` option is used by the [writefunction callback](#writefunction).
This can be any Perl data type, but the default [writefunction callback](#writefunction)
expects it to be a file handle, and the default value for `writedata` is
`STDOUT`.

( [CURLOPT\_WRITEDATA](https://curl.se/libcurl/c/CURLOPT_WRITEDATA.html) )

### writefunction

```perl
$curl->setopt( writefunction => sub ($curl, $content, $writedata) {
  ...
});
```

The `writefunction` callback will be called for each block of content
returned.  The content is passed as the second argument (the scalar uses
["window" in FFI::Platypus::Buffer](https://metacpan.org/pod/FFI::Platypus::Buffer#window) to efficiently expose the data
without having to copy it).  If an exception is thrown, then an
error will be passed back to curl (in the form of zero bytes
handled).

The callback also gets passed the [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) instance as
its first argument, and the [writedata](#writedata) option as its third argument.

( [CURLOPT\_WRITEFUNCTION](https://curl.se/libcurl/c/CURLOPT_WRITEFUNCTION.html) )

## unescape

```perl
my $unescaped = $curl->unescape($escaped);
```

This function converts the given URL encoded input string to a "plain
string" and returns that in an allocated memory area. All input characters
that are URL encoded (`%XX` where XX is a two-digit hexadecimal number) are
converted to their binary versions.

( [curl\_easy\_unescape](https://curl.se/libcurl/c/curl_easy_unescape.html) )

## upkeep

```
$curl->upkeep;
```

Some protocols have "connection upkeep" mechanisms. These mechanisms
usually send some traffic on existing connections in order to keep them
alive; this can prevent connections from being closed due to overzealous
firewalls, for example.

This function must be explicitly called in order to perform the upkeep
work. The connection upkeep interval is set with
[upkeep\_interval\_ms](https://metacpan.org/pod/Net::Swirl::CurlEasy::Options#upkeep_interval_ms).

Throws a
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
on error.

( [curl\_easy\_upkeep](https://curl.se/libcurl/c/curl_easy_upkeep.html) )

# EXCEPTIONS

In general methods should throw an exception object on failure.  In some cases [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy)
calls modules that may throw a string exception.

Here is how you might catch exceptions using the new `try` and `isa` features:

```perl
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
```

## Net::Swirl::CurlEasy::Exception

This is the base class for [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) exceptions.  It is an abstract class
in that you should only see sub class exceptions.

- as\_string

    A human readable diagnostic explaining the error, with the location from where the
    exception was thrown.  This looks like what a normal `warn` or `die` diagnostic
    would produce.  This is also what you get if you attempt to stringify the exception
    (`"$exception"`).

- filename

    The file in your code from which the exception was thrown.

- line

    The line number in your code from which the exception was thrown.

- package

    The package in your code from which the exception was thrown.

- strerror

    A human readable diagnostic explaining the error.

## Net::Swirl::CurlEasy::Exception::CurlCode

This is an exception that originated from `libcurl` and has a corresponding `CURLcode`.
It covers that vast majority of exceptions that you will see from this module.
It has these additional properties:

- code

    This is the integer `libcurl` code.  The full list of possible codes can be found here:
    [https://curl.se/libcurl/c/libcurl-errors.html](https://curl.se/libcurl/c/libcurl-errors.html).  Note that typically an exception for
    `CURLE_OK` is not normally thrown so you should not see that value in an exception.

## Net::Swirl::CurlEasy::Exception::Swirl

This is an exception that originates in [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) itself, or from
`libcurl` in a way that no `CURLcode` is provided.

- code

    This is the string code that classifies the type of exception.  You can check against
    these values as they should not change, where as the human readable `strerror` may
    change in the future without notice.  Possible values include:

    - `create-failed`

        `libcurl` was unable to create an instance.

    - `internal`

        An internal error.

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
[perform](#perform) to make the actual request.  The only **required** option is
[url](#url).  We also set [followlocation](#followlocation) to follow any redirects, since
our server PSGI redirects `/` to `/hello-world`.  If you did not set this option, then you would get the 301 response
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
[writedata](#writedata) option allows you to do this.  The default implementation treats this option as
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
[writefunction](#writefunction) option to define a callback function that will be called for
each chunk of the response.  The size of the chunks can vary depending on `libcurl`.  You
could have a large chunk or even a chunk of zero bytes!

You may have noticed that the [writefunction](#writefunction) callback takes two arguments,
the second of which we do not use.  This is the [writedata](#writedata) option.  As mentioned
in the previous example, the default `writefunction` callback treats this as a file handle,
but it could be any Perl data structure.

The default [writefunction](#writefunction) callback looks like this:

```perl
$curl->setopt( writefunction => sub ($, $data, $fh) {
  print $fh $data;
});
```

# SEE ALSO

- [Net::Swirl::CurlEasy::Options](https://metacpan.org/pod/Net::Swirl::CurlEasy::Options)

    Full list of options available to this API.

- [Net::Swirl::CurlEasy::Info](https://metacpan.org/pod/Net::Swirl::CurlEasy::Info)

    Full list of information items available to this API.

- [Net::Curl::Easy](https://metacpan.org/pod/Net::Curl::Easy)

    Older more mature XS based interface to the `libcurl` "easy" API.

- [Alien::curl](https://metacpan.org/pod/Alien::curl)

    [Alien](https://metacpan.org/pod/Alien) used by this module if no system `curl` can be found.

- [https://curl.se](https://curl.se)

    The `curl` homepage.

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
