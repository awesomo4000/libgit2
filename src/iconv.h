/*
 * Stub iconv.h — provides the iconv API backed by a pure-Zig NFC normalizer.
 * Shadows the system <iconv.h> so libgit2's fs_path.c links against our shim
 * instead of libiconv.
 */
#ifndef ICONV_SHIM_H
#define ICONV_SHIM_H

#include <stddef.h>

typedef void *iconv_t;

iconv_t iconv_open(const char *tocode, const char *fromcode);
size_t  iconv(iconv_t cd, char **restrict inbuf, size_t *restrict inbytesleft,
              char **restrict outbuf, size_t *restrict outbytesleft);
int     iconv_close(iconv_t cd);

#endif /* ICONV_SHIM_H */
