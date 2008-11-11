require 'mkmf'

have_library("krb5", "krb5_init_context")
have_library("gssapi_krb5", "gss_init_sec_context")
have_header("string.h")
have_header("krb5.h")
have_header("gssapi/gssapi.h")
have_header("gssapi/gssapi_krb5.h")
create_makefile("NsToken")
