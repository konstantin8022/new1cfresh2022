#!/bin/bash
# Add certificate using data defined in the $1.data.sh file

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

# configuration file name
C_CONF=$DIR/__ssl__.conf

# write configuration file
cat >$C_CONF <<EOL
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]
emailAddress = ${CERTIFICATE_EMAIL:-info@${CN}}
C            = ${CERTIFICATE_COUNTRY:-RU}
ST           = ${CERTIFICATE_STATE:-Moscow}
L            = ${CERTIFICATE_LOCALITY:-Moscow}
O            = ${CERTIFICATE_ORGANIZATION:-1C}
OU           = ${CERTIFICATE_UNIT:-Fresh}
CN           = ${CERTIFICATE_COMMON_NAME}

[req_ext]
subjectAltName = @alt_names

[alt_names]
EOL

for i in $(seq 1 9); do
    C_DOMAIN_NAME=CERTIFICATE_DOMAIN${i}
    if test ! -z "${!C_DOMAIN_NAME}" ; then
    cat >>$C_CONF <<EOL
DNS.$i  = ${!C_DOMAIN_NAME}
EOL
    fi
done

# check CERTIFICATE_COMMON_NAME variable
if test -z "${CERTIFICATE_COMMON_NAME}" ; then
  s_message "Certificate Common Name not defined in the file \"$1.data.sh\"."
  exit
fi

# get certificate Common Name
CN=$CERTIFICATE_COMMON_NAME

# certificate directory
CDIR=/etc/pki-custom

# get certificate FullName (without extension)
C_PATHNAME=$CDIR/$CN/$CN

#check if certificate exists
if test -d $CDIR/$CN ; then
  s_message "Certificates for \"$CDIR/$CN\" already contains in the \"$CDIR/$CN\" directory."
  rm -f $C_CONF
  exit
fi

s_message "Generate and install \"${CN}\" certificate"

s_message "1. Generate \"$CN\" certificate and store it to the \"$CDIR/$CN\" directory..."

#create certificate directory
mkdir $CDIR/$CN

# create \"$CN\" certificate using openssl
openssl req -new -newkey rsa:2048 -sha256 -nodes -x509 -days 3653 \
      -config $C_CONF -extensions 'req_ext' \
      -keyout $C_PATHNAME.key -out $C_PATHNAME.crt

# delete ssl configuration file
rm -f $C_CONF

# Convert \"$CN\" certificate to der format using openssl
openssl x509 -in $C_PATHNAME.crt -outform der -out $C_PATHNAME.der

# install certificate to OS using update-ca-certificates 
s_message "2. Install \"$CN\" certificate to the OS storage..."
cp $C_PATHNAME.crt /usr/local/share/ca-certificates/$CN.crt
update-ca-certificates

# install certificate to JRE using keytool
s_message "3. Install \"$CN\" certificate to the JRE storage..."

# JAVA variables
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java.*::")
JAVA_KEYTOOL=$JAVA_HOME/bin/keytool
JAVA_CERTS=$JAVA_HOME/lib/security/cacerts
KEYTOOL_PARM="-keystore $JAVA_CERTS -alias $CN -storepass changeit"

# add certificate to JRE storage using keytool
$JAVA_KEYTOOL -import -v -noprompt -file $C_PATHNAME.der $KEYTOOL_PARM
