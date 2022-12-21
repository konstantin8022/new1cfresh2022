#!/bin/bash
# Remove certificate with Common Name defined in the $1.data.sh file

function s_message {
  echo
  echo "$1"
  echo "$1" | sed 's/./-/g'
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
  echo Certificate Common Name not defined in file \"$DIR/$1.data.sh\".
  exit
fi

# get certificate Common Name
CN=$CERTIFICATE_COMMON_NAME

s_message "Remove \"${CN}\" certificate"

# certificates directory
CDIR=/etc/pki-custom/$CN

s_message "1. Remove the \"$CDIR\" directory..."

# delete certificate directory
if test ! -d "$CDIR" ; then
    echo "Directory \"$CDIR\" not found."
elif rm -rf "$CDIR" ; then
    echo "Directory \"$CDIR\" deleted..."
else
    echo "Error deleting \"$CDIR\" directory."
fi


s_message "2. Remove \"${CN}\" certificate from the OS storage..."

# remove certificate from OS storage using update-ca-certificates
CFILE=/usr/local/share/ca-certificates/$CN.crt
if test -f "$CFILE" ; then
    rm -f $CFILE
    echo "File \"$CFILE\" deleted."
    update-ca-certificates -f
else
    echo "File \"$CFILE\" not found."
fi

s_message "3. Remove \"${CN}\" certificate from the JRE storage..."

# remove certificate from JRE storage using keytool
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java.*::")
JAVA_KEYTOOL=$JAVA_HOME/bin/keytool
JAVA_CERTS=$JAVA_HOME/lib/security/cacerts
KEYTOOL_PARM="-keystore $JAVA_CERTS -alias $CN -storepass changeit"
KEYTOOL_ERR=$($JAVA_KEYTOOL -list -v $KEYTOOL_PARM | grep "keytool error:")

# delete certificate from JRE storage using keytool
if test -z "$KEYTOOL_ERR"; then
    $JAVA_KEYTOOL -delete -noprompt $KEYTOOL_PARM
    echo "Certificate \"$CN\" deleted from the JRE storage."
else
    echo "Certificate \"$CN\" not found in the JRE storage."
fi
