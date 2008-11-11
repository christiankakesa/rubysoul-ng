/*
** This file is part of RubySoul project.
**
** Test for the kerberos authentification.
**
** @author Christian KAKESA <christian.kakesa@gmail.com>
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <krb5.h>
#include <gssapi/gssapi.h>
#include <gssapi/gssapi_krb5.h>

#include "kerberos.h"

void	display_status(k_data_t *data)
{
	OM_uint32	minor, status;
	gss_buffer_desc	msg;

	gss_display_status(&minor, data->min, GSS_C_GSS_CODE, GSS_C_NO_OID, &status, &msg);
	if (msg.value) puts(msg.value);
	gss_display_status(&minor, data->maj, GSS_C_GSS_CODE, GSS_C_NO_OID, &status, &msg);
	if (msg.value) puts(msg.value);
}

krb5_error_code	get_new_tickets(	k_data_t *data,
					krb5_context context,
					krb5_principal principal,
					krb5_ccache ccache)
{
   krb5_error_code		ret;
   krb5_get_init_creds_opt	opt;
   krb5_creds			cred;
   char *			password = NULL;

   memset(&cred, 0, sizeof(cred));
   krb5_get_init_creds_opt_init (&opt);
   ret = krb5_get_init_creds_password(context,
                                      &cred,
                                      principal,
                                      data->unix_pass,
                                      krb5_prompter_posix,
                                      NULL,
                                      0,
                                      NULL,
                                      &opt);
   if (ret == KRB5_LIBOS_PWDINTR ||
       ret == KRB5KRB_AP_ERR_MODIFIED ||
       ret == KRB5KRB_AP_ERR_MODIFIED)
      return (1);
   else if (ret)
      return (2);
   if (krb5_cc_initialize(context, ccache, cred.client))
      return (3);
   if (krb5_cc_store_cred(context, ccache, &cred))
      return (3);
   //krb5_free_creds_contents(context, &cred);
   return (0);
}

int	my_init(k_data_t *data)
{
   krb5_error_code               ret;
   krb5_context                  context;
   krb5_ccache                   ccache;
   krb5_principal                principal;

   if (krb5_init_context(&context))
      return (1);

   if (!data->login ||
       krb5_build_principal(context, &principal, sizeof (NS_REALM) - 1, NS_REALM, data->login, 0))
      return (1);
   if (krb5_cc_default(context, &ccache))
      return (1);

   ret = get_new_tickets(data, context, principal, ccache);
   krb5_cc_close(context, ccache);
   krb5_free_principal(context, principal);
   krb5_free_context(context);
   return (ret);
}


void	import_name(k_data_t *data)
{
	OM_uint32		min;
	OM_uint32		maj;
	gss_buffer_desc		buf;

	buf.value = (unsigned char *) strdup(NS_SERVICE_NAME);
	buf.length = strlen((const char*)buf.value) + 1;
	maj = gss_import_name(&min, &buf, GSS_C_NT_HOSTBASED_SERVICE, &data->gss_name);

	if (maj != GSS_S_COMPLETE)
	      display_status(data);
}

void	init_context(k_data_t *data)
{
	OM_uint32	maj;
	/* gss_buffer_t	itoken      = GSS_C_NO_BUFFER; */
	krb5_enctype	etypes[]    = { ENCTYPE_DES3_CBC_SHA1, ENCTYPE_NULL };
	int		etype_count = sizeof(etypes) / sizeof(*etypes);
	gss_cred_id_t	credh;

	maj = gss_acquire_cred(	&data->min,
				GSS_C_NO_NAME,
				GSS_C_INDEFINITE,
				GSS_C_NO_OID_SET,
				GSS_C_INITIATE,
				&credh,
				NULL,
				NULL);
	if (maj != GSS_S_COMPLETE)
	{
		display_status(data);
		return;
	}
	maj = gss_krb5_set_allowable_enctypes(&data->min, credh, etype_count, etypes);
	if (maj != GSS_S_COMPLETE)
	{
		display_status(data);
		return;
	}
	data->ctx = GSS_C_NO_CONTEXT;
	maj = gss_init_sec_context(	&data->min,
					credh,
					&data->ctx,
					data->gss_name,
					GSS_C_NO_OID,
					GSS_C_CONF_FLAG,
					0,
					GSS_C_NO_CHANNEL_BINDINGS,
					data->itoken,
					NULL,
					&data->otoken,
					NULL,
					NULL);

	if (data->maj != GSS_S_COMPLETE)
		display_status(data);
}

int	check_tokens(k_data_t *data)
{
   import_name(data);
   init_context(data);

   if (!data->otoken.value)
   {
      my_init(data);
      import_name(data);
      init_context(data);
   }
   if (data->otoken.value)
      return (1);

   return (0);
}

/**
 * Encode string in base64
 */
unsigned char * base64_encode(const unsigned char *src, size_t len, size_t *out_len)
{
	unsigned char *out, *pos;
	const unsigned char *end, *in;
	size_t olen;
	int line_len;
	const unsigned char base64_table[65] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	olen = len * 4 / 3 + 4; /* 3-byte blocks to 4-byte */
	out = malloc(olen);
	if (out == NULL)
		return NULL;

	end = src + len;
	in = src;
	pos = out;
	while (end - in >= 3) {
		*pos++ = base64_table[in[0] >> 2];
		*pos++ = base64_table[((in[0] & 0x03) << 4) | (in[1] >> 4)];
		*pos++ = base64_table[((in[1] & 0x0f) << 2) | (in[2] >> 6)];
		*pos++ = base64_table[in[2] & 0x3f];
		in += 3;
	}

	if (end - in) {
		*pos++ = base64_table[in[0] >> 2];
		if (end - in == 1) {
			*pos++ = base64_table[(in[0] & 0x03) << 4];
			*pos++ = '=';
		} else {
			*pos++ = base64_table[((in[0] & 0x03) << 4) |
					      (in[1] >> 4)];
			*pos++ = base64_table[(in[1] & 0x0f) << 2];
		}
		*pos++ = '=';
		line_len += 4;
	}

	if (out_len)
		*out_len = pos - out;
	return out;
}

#if 0
int	main(int ac, char **av)
{
	k_data_t	*data;
	unsigned char		*token_base64;
	size_t			elen;

	data = calloc(1, sizeof (k_data_t));
	data->login = "kakesa_c";
	data->unix_pass = "eoxp[s1G";
	data->itoken = GSS_C_NO_BUFFER;
	check_tokens(data);
	token_base64 = base64_encode((const unsigned char*)data->otoken.value, data->otoken.length, &elen);
	puts(token_base64);
	gss_delete_sec_context(&data->min, &data->ctx, &data->otoken);
	free(data);
	return (0);
}
#endif
