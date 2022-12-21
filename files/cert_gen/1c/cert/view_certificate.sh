#!/bin/bash
# view certificate from the local directory, OS and JRE storages
# Common Name of the certificate given from the $1.data.sh file
# (CERTIFICATE_COMMON_NAME variable)

function s_message {
  echo
  echo "$1"
  echo "$1" | sed 's/./-/g'
}

function show_cert {
  if test -f "$1"; then
    openssl x509 -noout -certopt no_sigdump,no_pubkey -text -in $1
else
    echo "File $1 not found."
fi
}

if test -z "$1" ; then
    s_message "No argument supplied"
    exit 1
fi
 
# script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#check if file $1.data.sh exists
if test ! -f $DIR/$1.data.sh ; then
  s_message "File \"$DIR/$1.data.sh\" not found."
  exit 2
fi

# get configuration variables
. $DIR/$1.data.sh

# check CERTIFICATE_COMMON_NAME variable 
if test -z "${CERTIFICATE_COMMON_NAME}" ; then
  echo Certificate Common Name not defined in file \"$1.data.sh\".
  exit
fi

# get certificate Common Name
CN=$CERTIFICATE_COMMON_NAME

# certificates directory
CDIR=/etc/pki-custom

s_message "View \"$CN\" certificate"

s_message "1. View \"$CN\" certificate from the \"$CDIR/$CN\" directory..."

# view certificate from local directory using openssl
show_cert "$CDIR/$CN/$CN.crt"

s_message "2. View \"$CN\" certificate from the OS storage..."

# view certificate from OS storage using openssl
show_cert "/etc/ssl/certs/$CN.pem"

s_message "3. View \"$CN\" certificate from the JRE storage..."

JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java.*::")
JAVA_KEYTOOL=$JAVA_HOME/bin/keytool
JAVA_CERTS=$JAVA_HOME/lib/security/cacerts
KEYTOOL_PARM="-keystore $JAVA_CERTS -alias $CN -storepass changeit"
KEYTOOL_ERR=$($JAVA_KEYTOOL -list -v $KEYTOOL_PARM | grep "keytool error:")

# view certificate from JRE storage using keytool
if test -z "$KEYTOOL_ERR"; then
    $JAVA_KEYTOOL -list -v $KEYTOOL_PARM
else
    echo "Certificate \"$CN\" not found in the JRE storage."
fi

