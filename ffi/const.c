#include <ffi_platypus_bundle.h>
#include <curl/curl.h>

void
ffi_pl_bundle_constant(const char *package, ffi_platypus_constant_t *c)
{
  c->set_uint("CURLOPT_URL",           CURLOPT_URL          );
  c->set_uint("CURLOPT_WRITEFUNCTION", CURLOPT_WRITEFUNCTION);
}
