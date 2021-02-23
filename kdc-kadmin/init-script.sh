#!/bin/bash
echo "==================================================================================="
echo "==== Kerberos KDC and Kadmin ======================================================"
echo "==================================================================================="
KADMIN_PRINCIPAL_FULL=$KADMIN_PRINCIPAL@$REALM

echo "REALM: $REALM"
echo "KADMIN_PRINCIPAL_FULL: $KADMIN_PRINCIPAL_FULL"
echo "KADMIN_PASSWORD: $KADMIN_PASSWORD"
echo ""

echo "APPEND OPENLDAP HOSTNAME"
echo "172.16.238.10 	openldap.example.org" >> /etc/hosts

echo "==================================================================================="
echo "==== /etc/krb5.conf ==============================================================="
echo "==================================================================================="
KDC_KADMIN_SERVER=$(hostname -f)
tee /etc/krb5.conf <<EOF
[libdefaults]
	default_realm = $REALM

[realms]
	$REALM = {
		kdc_ports = 88,750
		kadmind_port = 749
		kdc = $KDC_KADMIN_SERVER
		admin_server = $KDC_KADMIN_SERVER
	}
EOF
echo ""

echo "==================================================================================="
echo "==== /etc/krb5kdc/kdc.conf ========================================================"
echo "==================================================================================="
tee /etc/krb5kdc/kdc.conf <<EOF
[realms]
	$REALM = {
		acl_file = /etc/krb5kdc/kadm5.acl
		max_renewable_life = 7d 0h 0m 0s
		supported_enctypes = $SUPPORTED_ENCRYPTION_TYPES
		default_principal_flags = +preauth
	}

[dbdefaults]
  ldap_kerberos_container_dn = "cn=krbContainer,dc=example,dc=org"

[dbmodules]
	openldap_ldapconf = {
			db_library = kldap
			disable_last_success = true
			ldap_kdc_dn = "cn=admin,dc=example,dc=org"
					# this object needs to have read rights on
					# the realm container and principal subtrees
			ldap_kadmind_dn = "cn=admin,dc=example,dc=org"
					# this object needs to have read and write rights on
					# the realm container and principal subtrees
			ldap_service_password_file = /tmp/keyfile/admin-service.keyfile
			ldap_servers = ldap://openldap:389
			ldap_conns_per_server = 5
	}

	$REALM = {
			db_library = kldap
			disable_last_success = true
			ldap_kdc_dn = "cn=admin,dc=example,dc=org"
					# this object needs to have read rights on
					# the realm container and principal subtrees
			ldap_kadmind_dn = "cn=admin,dc=example,dc=org"
					# this object needs to have read and write rights on
					# the realm container and principal subtrees
			ldap_service_password_file = /tmp/keyfile/admin-service.keyfile
			ldap_servers = ldap://openldap:389
			ldap_conns_per_server = 5
	}

EOF
echo ""

echo "==================================================================================="
echo "==== /etc/krb5kdc/kadm5.acl ======================================================="
echo "==================================================================================="
tee /etc/krb5kdc/kadm5.acl <<EOF
$KADMIN_PRINCIPAL_FULL *
noPermissions@$REALM X
EOF
echo ""

echo "==================================================================================="
echo "==== Creating realm ==============================================================="
echo "==================================================================================="
MASTER_PASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1)
kdb5_ldap_util create -w admin -D "cn=admin,dc=example,dc=org" -r $REALM -H ldap://openldap:389 -P $MASTER_PASSWORD  -subtrees "dc=example,dc=org" -s 
## This command also starts the krb5-kdc and krb5-admin-server services
#krb5_newrealm <<EOF
#$MASTER_PASSWORD
#$MASTER_PASSWORD
#EOF
echo ""

echo "==================================================================================="
echo "==== Create the principals in the acl ============================================="
echo "==================================================================================="
echo "Adding $KADMIN_PRINCIPAL principal"
kadmin.local -q "delete_principal -force $KADMIN_PRINCIPAL_FULL"
echo ""
kadmin.local -q "addprinc -x dn=uid=admin,dc=example,dc=org -pw $KADMIN_PASSWORD $KADMIN_PRINCIPAL_FULL"
echo ""
kadmin.local -q "addprinc -x dn=uid=user01,dc=example,dc=org -pw $USER01_PASSWORD $USER01_PRINCIPAL@$REALM"
echo ""
kadmin.local -q "addprinc -x dn=uid=user02,dc=example,dc=org -pw $USER02_PASSWORD $USER02_PRINCIPAL@$REALM"
echo ""

echo "Adding noPermissions principal"
kadmin.local -q "delete_principal -force noPermissions@$REALM"
echo ""
kadmin.local -q "addprinc -pw $KADMIN_PASSWORD noPermissions@$REALM"
echo ""

echo "==================================================================================="
echo "==== Run the services ============================================================="
echo "==================================================================================="
# We want the container to keep running until we explicitly kill it.
# So the last command cannot immediately exit. See
#   https://docs.docker.com/engine/reference/run/#detached-vs-foreground
# for a better explanation.

krb5kdc
kadmind -nofork