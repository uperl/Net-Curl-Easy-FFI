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

### activesocket

```perl
my $socket = $curl->getinfo('activesocket');
```

Returns the most recently active socket used for the transfer connection.  Will throw
an exception if the socket is no longer valid.  The active socket is typically only useful
in combination with [connect\_only](https://metacpan.org/pod/Net::Swirl::CurlEasy#connect_only), which skips the
transfer phase, allowing you to use the socket to implement custom protocols.

( [CURLINFO\_ACTIVESOCKET](https://curl.se/libcurl/c/CURLINFO_ACTIVESOCKET.html) )

### certinfo

```perl
$curl->setopt(certinfo => 1);
     ->perform;
my $certinfo = $curl->getinfo('certinfo');
```

For a TLS/SSL request, this will return information about the certificate chain, if you
set the [certinfo option](https://metacpan.org/pod/Net::Swirl::CurlEasy::Options#certinfo).  This will be returned
as list reference of list references.

( [CURLINFO\_CERTINFO](https://curl.se/libcurl/c/CURLINFO_CERTINFO.html) )

### lastsocket

```perl
my $socket = $curl->getinfo('activesocket');
```

This is just an alias for [activesocket](#activesocket).  In the C API  this info is
deprecated because it doesn't work correctly on 64 bit Windows.  Because it was deprecated
before [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) was written, this Perl API just makes this an alias
instead.

( [CURLINFO\_LASTSOCKET](https://curl.se/libcurl/c/CURLINFO_LASTSOCKET.html) )

### scheme

```perl
my $scheme = $curl->getinfo('scheme');
```

URL scheme used for the most recent connection done.

( [CURLINFO\_SCHEME](https://curl.se/libcurl/c/CURLINFO_SCHEME.html) )

### tls\_session

```perl
my $info = $curl->getinfo('tls_session');
my $backend = $info->backend;
my $internals = $info->internals;  # possibly implemented in a future version.
```

The C API for `libcurl` returns an integer code for the SSL/TSL backend, and an internal
pointer which can be used to access get additional information about the session.  For now
only the former is available via this Perl API.  In the future there may be an interface
to the latter as well.

The meaning of the integer codes of the `$backend` can be found here:
["curl\_sslbackend" in Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const#curl_sslbackend).

The actual class that implements `$info` may change in the future (including the class
name), but these two methods should be available (even if one just throws an exception).

( [CURLINFO\_TLS\_SESSION](https://curl.se/libcurl/c/CURLINFO_TLS_SESSION.html) )

### tls\_ssl\_ptr

```perl
my $info = $curl->getinfo('tls_ssl_ptr');
my $backend = $info->backend;
my $internals = $info->internals;  # possibly implemented in a future version.
```

The C API for `libcurl` returns an integer code for the SSL/TSL backend, and an internal
pointer which can be used to access get additional information about the session.  For now
only the former is available via this Perl API.  In the future there may be an interface
to the latter as well.

The meaning of the integer codes of the `$backend` can be found here:
["curl\_sslbackend" in Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const#curl_sslbackend).

Generally the [tls\_session option](#tls_session) is preferred when using the C API, but
until `internals` is implemented it doesn't make any difference for the Perl API.

The actual class that implements `$info` may change in the future (including the class
name), but these two methods should be available (even if one just throws an exception).

( [CURLINFO\_TLS\_SSL\_PTR](https://curl.se/libcurl/c/CURLINFO_TLS_SSL_PTR.html) )

## pause

```perl
$curl->pause($bitmask);
```

Using this function, you can explicitly mark a running connection to get paused, and you can
unpause a connection that was previously paused.  For full details on how this method
works, review the documentation of the function from the C API below.  You can import the
appropriate integer constants for `$bitmask` using the
[:pause tag](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const#CURLPAUSE) from [Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const).

Throws a
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode) on error.

( [curl\_easy\_pause](https://curl.se/libcurl/c/curl_easy_pause.html) )

## perform

```
$curl->perform;
```

Perform the curl request.  Throws a
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode) on error.

( [curl\_easy\_perform](https://curl.se/libcurl/c/curl_easy_perform.html) )

## recv

```perl
my $bytes_read = $curl->recv(\$buffer);
my $bytes_read = $curl->recv(\$buffer, $size);
```

This function receives raw data from the established connection. You may use it together
with the [send method](#send) to implement custom protocols. This functionality
can be particularly useful if you use proxies and/or SSL encryption: libcurl will take care
of proxy negotiation and connection setup.

`$buffer` is a scalar that will be written to.  It should be passed in as a reference to scalar
If `$size` is provided then `$buffer` will be allocated with at least `$size` bytes.

To establish a connection, set [connect\_only](#connect_only) to a true value before
calling the [perform method](#perform).  Note that this method does not work on connections
that were created without this option.

This method will normally return the actual number of bytes read, and the `$buffer`
will be updated.  If there is no data to be read, then `undef` will be returned.  You
can use `select` with [activesocket](#activesocket) to wait for data.

Wait on the socket only if `recv` returns `undef`.  The reason for this is `libcurl`
or the SSL library may internally cache some data, therefore you should call `recv`
until all data is read which would include any cached data.

Furthermore, if you wait on the socket and it tells you there is data to read `recv`
may return `undef` again if the only data that was read was for internal SSL processing,
and no other data is available.

This will throw
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
in the event of an error.

( [curl\_easy\_recv](https://curl.se/libcurl/c/curl_easy_recv.html) )

## reset

```
$curl->reset;
```

Resets all options previously set via the [setopt method](#setopt) to the
default values.  This puts the instance into the same state as when it was just
created.

It does not change the following information: live connections, the Session ID
cache, the DNS cache, the cookies, the shares or the alt-svc cache.

( [curl\_easy\_reset](https://curl.se/libcurl/c/curl_easy_reset.html) )

## send

```perl
my $bytes_written = $curl->send(\$buffer);
my $bytes_written = $curl->send(\$buffer, $offset);
```

This function sends arbitrary data over the established connection.  You may use it
together with the [recv method](#recv) to implement custom protocols.  This
functionality can be particularly useful if you use proxies and/or SSL encryption:
libcurl will take care of proxy negotiation and connection setup.

`$buffer` is the data to be sent.  It should be passed in as a reference to
a string scalar.  If `$offset` is provided, then the first `$offset` bytes will be
skipped.  This is useful if you are sending the rest of a buffer that was partially
sent on a previous call.

To establish a connection, set [connect\_only](#connect_only) to a true value before
calling the [perform method](#perform).  Note that this method does not work on connections
that were created without this option.

This method will normally return the actual number of bytes written.  If it is not
possible to send data right now, then `undef` will be returned.  You can use
`select` with [activesocket](#activesocket) to wait for the connection to be ready.

This will throw
[Net::Swirl::CurlEasy::Exception::CurlCode](#net-swirl-curleasy-exception-curlcode)
in the event of an error.

( [curl\_easy\_send](https://curl.se/libcurl/c/curl_easy_send.html) )

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

### connect\_only

```perl
$curl->setopt( connect_only => 1 );
```

Perform all the required proxy authentication and connection setup, but no data
transfer, and then return.  This is usually used in combination with
[activesocket](https://metacpan.org/pod/Net::Swirl::CurlEasy#activesocket).

This can be set to `2` and if HTTP or WebSocket are used the request will be
done, along with all response headers before handing over control to you.

Transfers marked connect only will not reuse any existing connections and
connections marked connect only will not be allowed to get reused.

( [CURLOPT\_CONNECT\_ONLY](https://curl.se/libcurl/c/CURLOPT_CONNECT_ONLY.html) )

### followlocation

```perl
$curl->setopt( followlocation => $bool );
```

Set this to 1 (the default is 0) to follow redirect responses.
The maximum number of redirects can be controlled by
[maxredirs](#maxredirs).

( [CURLOPT\_FOLLOWLOCATION](https://curl.se/libcurl/c/CURLOPT_FOLLOWLOCATION.html) )

### headerdata

```perl
$curl->setopt( headerdata => $headerdata);
```

This option sets the value of `$headerdata` that is passed into the callback of
the [headerfunction option](#headerfunction).

If the [headerfunction option](#headerfunction) is not set or set to `undef`
and this option is set to a true value, then the header data will be written
instead to the [writefunction callback](#writefunction).

( [CURLOPT\_HEADERDATA](https://curl.se/libcurl/c/CURLOPT_HEADERDATA.html) )

### headerfunction

```perl
$curl->setopt( headerfunction => sub ($curl, $content, $headerdata) {
  ...
});
```

This callback is called as each header is received.  The [headerdata option](#headerdata)
is used to set `$headerdata`.  For more details see the documentation for the
C API of this option:

( [CURLOPT\_HEADERFUNCTION](https://curl.se/libcurl/c/CURLOPT_HEADERFUNCTION.html) )

### httpheader

```perl
$curl->setopt( httpheader => \@headers );
```

This sets additional headers to add to your HTTP requests.  Each header **must not**
be CRLF-terminated, because that will confuse the server.  If you provide a
header that `libcurl` would normally add itself without a value (like `Accept:`),
then it will remove that header from the request.

( [CURLOPT\_HTTPHEADER](https://curl.se/libcurl/c/CURLOPT_HTTPHEADER.html) )

### maxredirs

```perl
$curl->setopt( maxredirs => $max );
```

Sets the maximum number of redirects.  Setting the limit to `0` will force
[Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) refuse any redirect.  Set to `-1` for an infinite
number of redirects.

( [CURLOPT\_MAXREDIRS](https://curl.se/libcurl/c/CURLOPT_MAXREDIRS.html) )

### noprogress

```perl
$curl->setopt( noprogress => $bool );
```

If `$bool` is `1` (the default) then the progress meter will not be used.
It also turns off calls to the [xferinfofunction callback](#xferinfofunction), so if
you want to use this callback set this value to `0`.

( [CURLOPT\_NOPROGRESS](https://curl.se/libcurl/c/CURLOPT_NOPROGRESS.html) )

### postfields

```perl
$curl->setopt( postfields => $postdata );
```

Set the full data to send in an HTTP POST operation.  If you use this option, then
`curl` will set the `Content-Type` to `application/x-www-form-urlencoded`,
so if you want to use a different encoding, then you should specify that using
the [httpheader option](#httpheader).  You want to set the [postfieldsize option](#postfieldsize)
before setting this one if you have any NULLs in your POST data.

( [CURLOPT\_POSTFIELDS](https://curl.se/libcurl/c/CURLOPT_POSTFIELDS.html) )

### postfieldsize

```perl
$curl->setopt( postfieldsize => $size );
```

The size of the POST data.  You want to set this before the [postfields option](#postfields)
if you have any NULLs in your POST data.

( [CURLOPT\_POSTFIELDSIZE](https://curl.se/libcurl/c/CURLOPT_POSTFIELDSIZE.html) )

### progressdata

```perl
$curl->setopt( progressdata => $progressdata );
```

\# TODO

( [CURLOPT\_PROGRESSDATA](https://curl.se/libcurl/c/CURLOPT_PROGRESSDATA.html))

### progressfunction

```perl
$curl->setopt( progressfunction => sub ($curl, $progressdata, $dltotal, $dlnow, $ultotal, $ulnow) {
  ...
});
```

\# TODO

( [CURLOPT\_PROGRESSFUNCTION](https://curl.se/libcurl/c/CURLOPT_PROGRESSFUNCTION.html))

### readdata

```perl
$curl->setopt( readdata => $readdata );
```

This is an arbitrary Perl data structure that will be passed into the
[readfunction callback](#readfunction).

( [CURLOPT\_READDATA](https://curl.se/libcurl/c/CURLOPT_READDATA.html) )

### readfunction

```perl
$curl->setopt( readfunction => sub ($curl, $maxsize, $readdata) {
  ...
});
```

Used to read in request body for `POST` and `PUT` requests.  The `$maxsize`
is the maximum size of the internal `libcur` buffer, so you should not return
more than that number of bytes.  If you do return more than the maximum, then
only the first `$maxsize` bytes will be passed on to `libcurl`.  `$readdata`
is the same object as passed in via the [readdata option](#readdata).

You can return either a string scalar or an array reference with three values.

```
return $buffer;
```

For a regular string the entire string data will be passed back to `libcurl`
up to the maximum of `$maxsize` bytes.

```
return [$buffer, $offset, $length];
```

For an array reference you can return a regular string scalar as the first
argument.  The other values `$offset` and `$length` are optional, and
determine a subset of the string that will be passed on to `libcurl`.
If `$offset` is provided then first `$offset` bytes will be ignored.
If `$length` is provided then only the `$length` bytes after the `$offset`
will be used.

This can be useful if you have a string scalar that is larger than `$maxsize`,
but do not want to copy parts of the scalar before returning them.

For a string reference

( [CURLOPT\_READFUNCTION](https://curl.se/libcurl/c/CURLOPT_READFUNCTION.html) )

### stderr

```perl
$curl->setopt( stderr => $fp );
```

This option is for the output of the [verbose option](#verbose) and the
default progress meter, which is enabled via the [noprogress option](#noprogress).

This option does NOT, as the name would suggest set `stderr`, that is just
the default value for this option.

The default value for this is the C `stderr` stream.  If you set this it
must be a C `FILE *` pointer, which you can get using [FFI::C::File](https://metacpan.org/pod/FFI::C::File).
You probably also need to close the file after the transfer completes
in order to get the full output.  For example:

```perl
use FFI::C::File;
use Path::Tiny qw( path );

my $fp = File::C::File->fopen("output.txt", "w");

$curl->setopt( stderr => $fp )
      ->setopt( verbose => 1 )
      ->setopt( noprogress => 0 )
      ->perform;

$fp->fclose;

my $verbose_and_progress = path("output.txt")->slurp_raw;
```

Unfortunately the [noprogress option](#noprogress) needs to be set to `0`
for the [progressfunction callback](#progressfunction) or the
[xferinfofunction callback](#xferinfofunction), but setting either of those
does not turn off the default progress meter (!) so when using those options
you may want to set this to something else.

( [CURLOPT\_STDERR](https://curl.se/libcurl/c/CURLOPT_STDERR.html) )

### url

```perl
$curl->setopt( url => $url );
```

The URL to work with.  This is the only required option.

( [CURLOPT\_URL](https://curl.se/libcurl/c/CURLOPT_URL.html) )

### verbose

```perl
$curl->setopt( verbose => 1 );
```

Set this to `1` to make the library display a lot of verbose information about its
operations.  Useful for `libcurl` and/or protocol debugging and understanding.

You hardly ever want to set this in production, you almost always want this when you
debug/report problems.

( [CURLOPT\_VERBOSE](https://curl.se/libcurl/c/CURLOPT_VERBOSE.html) )

### writedata

```perl
$curl->setopt( writedata => $writedata );
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

### xferinfodata

```perl
$curl->setopt(xferinfodata => $xferinfodata );
```

The `xferinfodata` option is used by the [xferinfofunction callback](#xferinfofunction).
This can be any Perl data type.  It is unused by `libcurl` itself.

( [CURLOPT\_XFERINFODATA](https://curl.se/libcurl/c/CURLOPT_XFERINFODATA.html))

### xferinfofunction

```perl
$curl->setopt(xferinfofunction => sub ($curl, $xferinfodata, $dltotal, $dlnow, $ultotal, $ulnow) {
  ...
});
```

This gets called during the transfer "with a frequent interval".  `$xferinfodata` is the
data passed into the [xferinfodata option](#xferinfodata).  The [noprogress option](#noprogress)
must be set to `0` otherwise this callback will not be called.

( [CURLOPT\_XFERINFOFUNCTION](https://curl.se/libcurl/c/CURLOPT_XFERINFOFUNCTION.html) )

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

In general methods should throw an exception object that is a subclass of [Exception::FFI::ErrorCode](https://metacpan.org/pod/Exception::FFI::ErrorCode).
In some cases [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) calls modules that may throw string exceptions. When identified,
these should be converted into object exceptions (Please open an issue if you see this behavior).

Here is how you might catch exceptions using the new `try` and `isa` features:

```perl
use Net::Swirl::CurlEasy qw( :all );
use experimental qw( try isa );

try {
  Net::Swirl::CurlEasy
    ->new
    ->setopt( url => 'https://alienfile.org' )
    ->perform;
} catch ($e) {
  if($e isa Net::Swirl::CurlEasy::Exception::CurlCode) {

   # get the integer code
   my $code = $e->code;
   if($e->code == CURLE_UNSUPPORTED_PROTOCOL) {
     ...
   } elsif($e->code == CURLE_FAILED_INIT) {
     ...
   } elsif($e->code == CURLE_URL_MALFORMAT) {
     ...
   }
   ...


  } elsif($e isa Net::Swirl::CurlEasy::Exception::CurlCode) {

   if($e->code == SWIRL_CREATE_FAILED) {
     # the constructor failed to create an instance
     # rare
   } elsif($e->code == SWIRL_BUFFER_REF) {
     # passed the wrong arguments to a function that was
     # expecting a buffer
   }

  } else {
    # some exception not coming directly from libcurl or Swirl
  }
}
```

## base class

The base class for all exceptions that this class throws should be
[Exception::FFI::ErrorCode::Base](https://metacpan.org/pod/Exception::FFI::ErrorCode).  Please
see [Exception::FFI::ErrorCode](https://metacpan.org/pod/Exception::FFI::ErrorCode) for details on the base class.

## Net::Swirl::CurlEasy::Exception::CurlCode

This is an exception that originated from `libcurl` and has a corresponding `CURLcode`.
It covers that vast majority of exceptions that you will see from this module.
It has these additional properties:

- code

    This is the integer `libcurl` code.  The full list of possible codes can be found here:
    [https://curl.se/libcurl/c/libcurl-errors.html](https://curl.se/libcurl/c/libcurl-errors.html).  Note that typically an exception for
    `CURLE_OK` is not normally thrown so you should not see that value in an exception.

    `CURLE_AGAIN` (81) is usually caught by the [send](#send) and [recv](#recv) methods
    which instead return `undef` when socket is not ready.

    If you want to use the constant names from the C API, you can import them from
    [Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const).

## Net::Swirl::CurlEasy::Exception::Swirl

This is an exception that originates in [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) itself, or from
`libcurl` in a way that no `CURLcode` is provided.

- code

    This is the integer error code.  You can import these from [Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const)
    using the `:swirl_errorcode` or `:all` tags.

    - `SWIRL_BUFFER_REF`

        The [send](#send) and [recv](#recv) methods take a reference to a string scalar, and
        you passed in something else.

    - `SWIRL_CREATE_FAILED`

        `libcurl` was unable to create an instance.

    - `SWIRL_INTERNAL`

        An internal error.

    - `SWIRL_NOT_IMPLEMENTED`

        You called a method, function or option that is not yet implemented.

# EXAMPLES

All of the examples are provided in the `examples` subdirectory of this distribution.

These examples will work against this very simple PSGI app that you can run locally.

```perl
use warnings;
use 5.020;
use experimental qw( signatures postderef );

package Plack::App::HelloWorld {

  use JSON::PP qw( encode_json decode_json );
  use parent qw( Plack::Component );

  sub call ($self, $env) {
    my $path = $env->{PATH_INFO} || '/';
    return $self->return_404 if $path =~ /\0/;

    if($path eq '/hello-world') {
      return [200, ['Content-Type' => 'text/plain'], ["Hello World!\n"]];
    }

    if($path eq '/show-req-headers') {
      my %headers = map { lc($_ =~ s/^HTTP_//r) => $env->{$_}} grep /^HTTP_/, keys $env->%*;
      return [200, ['Content-Type' => 'application/json'], [encode_json(\%headers)]];
    }

    if($path eq '/show-res-headers') {
      return [200, ['Content-Type' => 'text/plain', Foo => 'Bar', Baz => 1], ["Check the headers\n"]];
    }

    if($path eq '/post' && $env->{REQUEST_METHOD} eq 'POST') {
      my $data = '';
      $env->{'psgi.input'}->read($data, $env->{CONTENT_LENGTH});
      $data = decode_json($data);
      %$data = reverse %$data;
      return [200, ['Content-Type' => 'application/json'], [encode_json $data]];
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

## Debug Transfer With verbose Option

### source

```perl
use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000')
     ->setopt(followlocation => 1)
     ->setopt(verbose => 1)
     ->perform;
```

### execute

```perl
$ perl examples/verbose.pl
*   Trying 127.0.0.1:5000...
* Connected to localhost (127.0.0.1) port 5000 (#0)
> GET / HTTP/1.1
Host: localhost:5000
Accept: */*

* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 301 Moved Permanently
< Date: Mon, 03 Oct 2022 22:41:29 GMT
< Server: HTTP::Server::PSGI
< Location: /hello-world
< Content-Length: 0
<
* Closing connection 0
* Issue another request to this URL: 'http://localhost:5000/hello-world'
* Hostname localhost was found in DNS cache
*   Trying 127.0.0.1:5000...
* Connected to localhost (127.0.0.1) port 5000 (#1)
> GET /hello-world HTTP/1.0
Host: localhost:5000
Accept: */*

* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 200 OK
< Date: Mon, 03 Oct 2022 22:41:29 GMT
< Server: HTTP::Server::PSGI
< Content-Type: text/plain
< Content-Length: 13
<
Hello World!
* Closing connection 1
```

### notes

If you set the [verbose option](#verbose) you will get a lot of extra information about
the transfer.  This is equivalent to using the `-v` flag with the `curl` command.  You
normally would not want to do this programmatically with content that you want to capture,
but it can be useful for debugging transfers.

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

## Make a POST Request

### source

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use JSON::PP qw( decode_json );
use Data::Dumper qw( Dumper );

my $curl = Net::Swirl::CurlEasy->new;

my $post_body = '{"foo":"bar","baz":1}';

my @res;

$curl->setopt(url => 'http://localhost:5000/post')
     ->setopt(post           => 1)
     ->setopt(httpheader     => ['Content-Type: application/json'])
     ->setopt(postfieldsize  => length($post_body))
     ->setopt(postfields     => $post_body)
     ->setopt(writefunction  => sub ($, $data, $) {
       push @res, $data;
     })
     ->perform;

my $res = decode_json(join('',@res));

$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

say Dumper($res);
```

### execute

```perl
$ perl examples/post.pl
{
  '1' => 'baz',
  'bar' => 'foo'
}
```

### notes

Here we are using the `POST` method on the `/post` path on our little test server, which
just takes a `POST` request as JSON object and reverses the keys for the values.  If we
do not specify the `Content-Type`, then `libcurl` will use `application/x-www-form-urlencoded`,
so we explicitly set this to the MIME type for JSON.

Unless you are doing chunked encoding, you want to be careful to set the
[postfieldsize option](#postfieldsize) before setting the [postfields option](#postfields),
if you have any NULLs in your request body, because `curl` will assume a NULL terminated
string if you do not.

The rest of this should look very familiar, we gather up the response using the
[writefunction callback](#writefunction) and decode it from JSON and print it out using
[Data::Dumper](https://metacpan.org/pod/Data::Dumper).

If you want to handle larger or streamed request bodies, then you will want to instead use
the [readfunction callback](#readfunction) and possibly the [readdata option](#readdata).

## Set or Remove Arbitrary Request Headers

### source

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;
use Data::Dumper qw( Dumper );
use JSON::PP qw( decode_json );

my $curl = Net::Swirl::CurlEasy->new;

my @raw;

$curl->setopt(url => 'http://localhost:5000/show-req-headers')
     ->setopt(httpheader => ["Shoesize: 10", "Accept:"])
     ->setopt(writefunction => sub ($, $data, $) {
       push @raw, $data;
     })
     ->perform;

my $data = decode_json(join('', @raw));

$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;

say Dumper($data);
```

### execute

```perl
$ perl examples/req-header.pl
{
  'host' => 'localhost:5000',
  'shoesize' => '10'
}
```

### notes

The [httpheader option](https://metacpan.org/pod/Net::Swirl::CurlEasy::Options#httpheader) allows you to set and
remove arbitrary request headers.  In this example, we set the non-standard `Shoesize`
header to the size `10`.  We also set `Accept` to nothing, which tells `libcurl` not
to include this header.  (If you modified this example to not set that header  you would
see it come back as `*/*`).

## Get Response Headers

### source

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000/show-res-headers')
     ->setopt(headerfunction => sub ($, $data, $) {
       chomp $data;
       say "header: $data";
     })
     ->perform;
```

### execute

```
$ perl examples/res-header.pl
header: HTTP/1.0 200 OK
header: Date: Tue, 04 Oct 2022 20:39:48 GMT
header: Server: HTTP::Server::PSGI
header: Content-Type: text/plain
header: Foo: Bar
header: Baz: 1
header: Content-Length: 18
header:
Check the headers
```

### notes

The [headerfunction callback](#headerfunction) works a lot like the [writefunction callback](#writefunction)
seen earlier.  It is called once for each header, so you can parse individual headers
inside the callback without having to wait for the rest of the header data.

We do not use it in this example, but the [headerdata option](#headerdata) is used to
pass any Perl object into the callback, just like [writedata option](#writedata) is
used to pass any Perl object into the [writefunction callback](#writefunction).

## Parse the Entire Response Using Perl

### source

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use HTTP::Response;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

my @raw;

$curl->setopt(url => 'http://localhost:5000/show-res-headers')
     ->setopt(headerdata => 1)
     ->setopt(writefunction => sub ($, $chunk, $) {
       push @raw, $chunk
     })
     ->perform;

my $res = HTTP::Response->parse(join('', @raw));

say 'The Foo Header Was: ', $res->header('foo');
say 'The Content Was:    ', $res->decoded_content;
```

### execute

```
$ perl examples/res-parse.pl
The Foo Header Was: Bar
The Content Was:    Check the headers
```

### notes

If you do not set the [headerfunction callback](#headerfunction) (or set it to `undef`),
and set [headerdata option](#headerdata) to a true value, then the header data will be
sent to the [writefunction callback](#writefunction).  This is a good way to capture and
parse the entire response.  Here we pass the raw response into the [HTTP::Response](https://metacpan.org/pod/HTTP::Response)
class to parse it, which we can then use to interrogate it.

Note that we use the `decoded_content` method on [HTTP::Response](https://metacpan.org/pod/HTTP::Response) to make sure that the
content part of the response is correctly decoded.  In this case we could probably just
use content method instead, but this is a good example of how you could decode the content
of a HTTP response from `libcurl` if you had to.

## Get Information About the Request After the Transfer

### source

```perl
use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url => 'http://localhost:5000/hello-world')
     ->perform;

say "The Content-Type is: ", $curl->getinfo('content_type');
```

### execute

```
$ perl examples/getinfo.pl
Hello World!
The Content-Type is: text/plain
```

### notes

After calling the [perform method](#perform) there is plethora of information available via
the [getinfo method](#getinfo).  The full list is available from [Net::Swirl::CurlEasy::Info](https://metacpan.org/pod/Net::Swirl::CurlEasy::Info)
with more details on the `curl` website: [https://curl.se/libcurl/c/curl\_easy\_getinfo.html](https://curl.se/libcurl/c/curl_easy_getinfo.html).

In this example we get the `Content-Type` and print it out.

## Connect Securely With Mutual TLS/SSL Encryption and Verification

### source

```perl
use warnings;
use 5.020;
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

$curl->setopt(url            => 'https://localhost:5001/hello-world')
     ->setopt(ssl_verifypeer => 1)
     ->setopt(cainfo         => 'examples/tls/Swirl-CA.crt')
     ->setopt(sslcert        => 'examples/tls/client.crt')
     ->setopt(sslkey         => 'examples/tls/client.key')
     ->setopt(keypasswd      => 'password')
     ->setopt(verbose => 1)
     ->perform;

die "unable to make request" unless $curl->getinfo('response_code') == 200;
```

### execute

```perl
$ perl examples/simplessl.pl
*   Trying 127.0.0.1:5001...
* Connected to localhost (127.0.0.1) port 5001 (#0)
* ALPN: offers h2
* ALPN: offers http/1.1
*  CAfile: examples/tls/Swirl-CA.crt
*  CApath: none
* SSL connection using TLSv1.2 / ECDHE-RSA-AES256-GCM-SHA384
* ALPN: server accepted http/1.1
* Server certificate:
*  subject: CN=localhost
*  start date: Oct  4 10:57:17 2022 GMT
*  expire date: Jan  6 10:57:17 2025 GMT
*  subjectAltName: host "localhost" matched cert's "localhost"
*  issuer: CN=Snakeoil Swirl CA
*  SSL certificate verify ok.
> GET /hello-world HTTP/1.1
Host: localhost:5001
Accept: */*

* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.22.0
< Date: Tue, 04 Oct 2022 12:53:32 GMT
< Content-Type: text/plain
< Content-Length: 13
< Connection: keep-alive
<
Hello World!
* Connection #0 to host localhost left intact
```

### prereqs

Setting up a Certificate Authority (CA) and generating the appropriate certificates
is beyond the scope of this discussion, so we've pre-generated the appropriate
files in the `examples/tls` directory so that the example can be run.  Hopefully
it is obvious that you should never use these files for in a production environment
since the "private" keys are completely public.

This directory also contains an `nginx` configuration that will proxy to the plackup
server.  To start it you will need to install nginx and run:

```
$ nginx -p examples/tls -c nginx.conf
```

### notes

Once you have TLS/SSL certificates and keys and your server is correctly set up
it is pretty easy to use [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy) so that it is secure using both
encryption and verification.

First we set these options:

- `ssl_verifypeer`

    We set this to `1`, although this is the default.  If we don't want to verify
    that the server has a valid certificate then we can set this to `0`.  This
    is roughly equivalent to `curl`'s `-k` option.

- `cainfo`

    This is the Certificate Authority (CA) public certificate.  If you set
    `ssl_verifypeer` to false, then you do not need this.

- `sslcert` and `sslkey`

    This is the public client certificate and private key.  If the server does not
    require client key, then you do not need these.

- `keypasswd`

    This is the password with which the private client key was encrypted.  We use
    the obviously terrible password \`password\` just to show how you would specify
    a password.

- `verbose`

    We also set the `verbose` flag here once again just so that we can see some
    of the details of the SSL/TLS interaction.

Then once the transfer has completed using the [perform method](#perform),
we get the [response code](https://metacpan.org/pod/Net::Swirl::CurlEasy::Info#response_code) to
ensure that the request was correctly accepted.  If the server does not like
our key, then it will return a 4xx error.

## Implement Protocols With send and recv

### source

```perl
use warnings;
use 5.020;
use experimental qw( signatures );
use Net::Swirl::CurlEasy;

my $curl = Net::Swirl::CurlEasy->new;

# 1. connectonly
$curl->setopt(url => 'http://localhost:5000')
     ->setopt(connect_only => 1)
     ->perform;

# 2. utility function
sub wait_on_socket ($sock, $for_recv=undef) {
  my $vec = '';
  vec($vec, $sock, 1) = 1;
  if($for_recv) {
    select $vec, undef, undef, 60000;
  } else {
    select undef, $vec, undef, 60000;
  }
}

# 3. activesocket
my $sock = $curl->getinfo('activesocket');

my $so_far = 0;
my $req = join "\015\012", 'GET /hello-world HTTP/1.2',
                           'Host: localhost',
                           'User-Agent: Foo/Bar',
                           '','';

while(1) {
  # 4. send
  my $bs = $curl->send(\$req, $so_far);

  unless(defined $bs) {
    wait_on_socket $sock;
    next;
  }

  $so_far += $bs;

  last if $so_far == length $req;
}

my $res;

while(1) {
  # 5. recv
  my $br = $curl->recv(\my $data, 4);

  unless(defined $br) {
    wait_on_socket $sock, 1;
    next;
  }

  last if $br == 0;

  $res .= $data;
}

say $res;
```

### execute

```
$ perl examples/connect-only.pl
HTTP/1.0 200 OK
Date: Mon, 03 Oct 2022 20:27:07 GMT
Server: HTTP::Server::PSGI
Content-Type: text/plain
Content-Length: 13

Hello World!
```

### notes

The combination of the [connect\_only option](#connect_only), [activesocket info](#activesocket),
[send method](#send) and [recv method](#recv) allow you to implement your own protocols.  This can
be useful way to delegate TLS/SSL and proxies to this module to let you implement something a
custom protocol.  If you are trying to implement HTTP, as is demonstrated instead of using
`curl`'s own HTTP transport then you may be doing something wrong, but this serves as a simple
example of how you would use this technique.

1. First of all we set the [connect\_only option](#connect_only) to `1`.  `curl` will establish
the connection (we don't use TLS/SSL or any proxies here, but if we did configure `$curl` to
use them then they would be handled for us), but does not send the HTTP request.
2. Next we have a utility function `wait_on_socket` which waits for a socket to be either be ready
for writing, or have bytes ready to be read.
3. We can use the [getinfo method](#getinfo) with [activesocket](#activesocket) to get the already
opened socket.  Note that we MUST NOT read or write to this socket directly, and should instead
use the [send](#send) and [recv](#recv) methods instead.
4. Now we are ready to send our HTTP request using the [send method](#send).  This method will
return either `undef` if the connection is not ready for writing, or the number of bytes that
were actually written.  The optional second argument to the [send method](#send) is an offset
in the buffer.  This allows us to send just the remaining portion of the request if we have
already sent part of it.
5. Finally we can use the [recv method](#recv) to fetch the response.  Once again the data might
not be ready yet, and may come in chunks so we have to check the return value.  If it returns
`undef` then we should once again wait on the socket, this time for bytes to read.  Otherwise
We can append the data to the response buffer that we are building up.  When there are no
more bytes to read we can assume the response is complete.

# SEE ALSO

- [Net::Swirl::CurlEasy::Const](https://metacpan.org/pod/Net::Swirl::CurlEasy::Const)

    Full list of constants used by [Net::Swirl::CurlEasy](https://metacpan.org/pod/Net::Swirl::CurlEasy).

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
