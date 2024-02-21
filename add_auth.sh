#!/bin/sh
if [ "x$HTPASSWD_FILE" != "x" ] && [ "x$PASSWD_REALM" != "x" ]
then if [ $1 = "auth_backend" ]
  then cat <<EOF
var.htpasswd_file           = env.HTPASSWD_FILE
var.passwd_realm            = env.PASSWD_REALM
auth.backend                = "htpasswd"
auth.backend.htpasswd.userfile = var.htpasswd_file
EOF
  else cat <<EOF
auth.require = ("$1" =>
                ("method" => "basic",
                 "realm" => var.passwd_realm,
                 "require" => "valid-user")
               )
EOF
  fi
fi