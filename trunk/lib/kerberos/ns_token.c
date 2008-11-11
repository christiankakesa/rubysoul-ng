/*
** This file is part of RubySoul project.
**
** Test for the kerberos authentification.
**
** @author Christian KAKESA <christian.kakesa@gmail.com>
*/

#include <ruby.h>

#include "kerberos.h"

VALUE cNsToken;

static VALUE k_init(VALUE self)
{
	rb_define_attr(cNsToken, "login", 1, 1);
	rb_define_attr(cNsToken, "password", 1, 1);
	rb_define_attr(cNsToken, "token", 1, 0);
	rb_define_attr(cNsToken, "token_base64", 1, 0);
	return self;
}

static VALUE k_get_token(VALUE self, VALUE login, VALUE password)
{
	k_data_t	*data;
	unsigned char	*token_base64;
	unsigned char	*token;
	size_t		elen;

	data = calloc(1, sizeof (k_data_t));
	data->login = STR2CSTR(login);
	data->unix_pass = STR2CSTR(password);
	data->itoken = GSS_C_NO_BUFFER;
	if (check_tokens(data) != 1)
		return Qfalse;

	token = strdup((const unsigned char*)data->otoken.value);
	token_base64 = base64_encode((const unsigned char*)data->otoken.value, data->otoken.length, &elen);
	rb_iv_set(self, "@login", login);
	rb_iv_set(self, "@password", password);
	rb_iv_set(self, "@token", rb_str_new2(token));
	rb_iv_set(self, "@token_base64", rb_str_new2(token_base64));
	free(token);
	free(token_base64);
	free(data);
	return Qtrue;
}

void Init_NsToken()
{
	cNsToken = rb_define_class("NsToken", rb_cObject);
	rb_define_method(cNsToken, "initialize", k_init, 0);
	rb_define_method(cNsToken, "get_token", k_get_token, 2);
}
