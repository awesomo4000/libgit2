/*
 * transport_stubs.c — no-op stubs for libgit2 transport/stream/remote symbols.
 *
 * When enable-transports=false, the transport/stream/network .c files are not
 * compiled. However, some core sources (libgit2.c, settings.c, branch.c,
 * submodule.c) still reference symbols defined in those files. This file
 * provides harmless stubs so the linker is satisfied.
 *
 * All functions return GIT_ENOTFOUND (-3) or are void no-ops.
 * All global variables are initialized to safe defaults (0 / false).
 */

#include <stddef.h>    /* NULL, size_t */
#include <stdbool.h>   /* bool */

#include "git2/types.h"
#include "git2/strarray.h"

/* Forward declarations for opaque types used in signatures */
typedef struct git_clone_options git_clone_options;
typedef struct git_fetch_options git_fetch_options;

/* ------------------------------------------------------------------ */
/* Global init functions (called from init_fns[] in libgit2.c)        */
/* ------------------------------------------------------------------ */

int git_transport_ssh_libssh2_global_init(void) { return 0; }
int git_stream_registry_global_init(void)       { return 0; }
int git_socket_stream_global_init(void)         { return 0; }
int git_openssl_stream_global_init(void)        { return 0; }
int git_mbedtls_stream_global_init(void)        { return 0; }

/* ------------------------------------------------------------------ */
/* Global tuneable variables (referenced by settings.c)               */
/* ------------------------------------------------------------------ */

int  git_socket_stream__connect_timeout = 0;
int  git_socket_stream__timeout         = 0;
bool git_smart__ofs_delta_enabled       = true;
bool git_http__expect_continue          = false;

/* ------------------------------------------------------------------ */
/* Remote functions (referenced by branch.c, submodule.c)             */
/* ------------------------------------------------------------------ */

int git_remote_create(
	git_remote **out,
	git_repository *repo,
	const char *name,
	const char *url)
{
	(void)out; (void)repo; (void)name; (void)url;
	return -3; /* GIT_ENOTFOUND */
}

int git_remote_lookup(
	git_remote **out,
	git_repository *repo,
	const char *name)
{
	(void)out; (void)repo; (void)name;
	return -3; /* GIT_ENOTFOUND */
}

int git_remote_fetch(
	git_remote *remote,
	const git_strarray *refspecs,
	const git_fetch_options *opts,
	const char *reflog_message)
{
	(void)remote; (void)refspecs; (void)opts; (void)reflog_message;
	return -3; /* GIT_ENOTFOUND */
}

void git_remote_free(git_remote *remote)
{
	(void)remote;
}

int git_remote_list(
	git_strarray *out,
	git_repository *repo)
{
	(void)out; (void)repo;
	return -3; /* GIT_ENOTFOUND */
}

const char *git_remote_url(const git_remote *remote)
{
	(void)remote;
	return NULL;
}

git_refspec *git_remote__matching_refspec(
	git_remote *remote,
	const char *refname)
{
	(void)remote; (void)refname;
	return NULL;
}

git_refspec *git_remote__matching_dst_refspec(
	git_remote *remote,
	const char *refname)
{
	(void)remote; (void)refname;
	return NULL;
}

/* ------------------------------------------------------------------ */
/* Clone (referenced by submodule.c)                                  */
/* ------------------------------------------------------------------ */

int git_clone__submodule(
	git_repository **out,
	const char *url,
	const char *local_path,
	const git_clone_options *options)
{
	(void)out; (void)url; (void)local_path; (void)options;
	return -3; /* GIT_ENOTFOUND */
}
