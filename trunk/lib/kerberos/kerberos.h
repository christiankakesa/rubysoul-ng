/*
** This file is part of RubySoul project.
**
** Test for the kerberos authentification.
**
** @author Christian KAKESA <christian.kakesa@gmail.com>
*/

#ifndef __KERBEROS_H_
#define __KERBEROS_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <krb5.h>
#include <gssapi/gssapi.h>
#include <gssapi/gssapi_krb5.h>

#define NS_SERVICE_NAME	"host@ns-server.epitech.net"
#define NS_REALM	"EPITECH.NET"

typedef struct k_data
{
	char*		login;
	char*		unix_pass;
	OM_uint32	min;
	OM_uint32	maj;
	gss_name_t	gss_name;
	gss_ctx_id_t	ctx;
	gss_buffer_t	itoken;
	gss_buffer_desc	otoken;
}	k_data_t;

void
display_status(k_data_t *data);

krb5_error_code
get_new_tickets(	k_data_t *data,
			krb5_context context,
			krb5_principal principal,
			krb5_ccache ccache);

int
my_init(k_data_t *data);

void
import_name(k_data_t *data);

void
init_context(k_data_t *data);

int
check_tokens(k_data_t *data);

unsigned char *
base64_encode(const unsigned char *src, size_t len, size_t *out_len);

#endif /* !__KERBEROS_H_ */
