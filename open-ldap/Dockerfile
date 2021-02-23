FROM osixia/openldap:1.5.0

ENV KRB5_KTNAME "FILE:/etc/ldap/openldap.keytab"

# COPY Kerberos schema to LDAP Schema directory
# without this schema Kerberos can't manage principals and realms into the LDAP
COPY kerberos.ldif /etc/ldap/schema/
COPY kerberos.schema /etc/ldap/schema/
COPY krb5.conf /etc/
COPY krb-acl.ldif /tmp/
COPY krb-acl-1.ldif /tmp/
COPY krb-acl-2.ldif /tmp/
COPY krb-acl-3.ldif /tmp/
COPY krb-acl-4.ldif /tmp/
COPY krb-acl-5.ldif /tmp/
COPY users.ldif /tmp/

RUN echo "ASL_MECH GSSAPI" >> /.ldaprc
#COPY slapd.conf /usr/lib/sasl2/ 
