#!/bin/bash

chk_var () {
   eval var=\$$1
   if [ -z "$var" ]; then
       if [ -z "$2" ]; then
           echo "err:  Enviroment vaiable \$$1 is not set."
           exit 1
       else
           export "$1"="$2"
       fi
   fi
   
}

load_defaults()
{
    chk_var  TZ                    "utc"
    chk_var  WEBSERVER             "nginx"
    chk_var  FORCE_HTTPS           true
    chk_var  NGINX_CACHE           false
    chk_var  SPAM_SIEVE            true
    chk_var  SPAM_SIEVE_TIMEOUT    "15m"
    chk_var  FAIL2BAN              true
    chk_var  DKIM                  true
    chk_var  KOLAB_RCPT_POLICY     "false"
    chk_var  KOLAB_DEFAULT_LOCALE  "en_US"
    chk_var  MAX_MEMORY_SIZE       "256M"
    chk_var  MAX_FILE_SIZE         "30M"
    chk_var  MAX_MAIL_SIZE         "30M"
    chk_var  MAX_MAILBOX_SIZE      "50M"
    chk_var  MAX_BODY_SIZE         "50M"
    chk_var  ROUNDCUBE_SKIN        "chameleon"
    chk_var  ROUNDCUBE_ZIPDOWNLOAD true
    chk_var  ROUNDCUBE_TRASH       "trash"
    chk_var  CERT_PATH             "/etc/pki/tls/kolab"
}

set_timezone()
{
    if [ -f /usr/share/zoneinfo/$TZ ]; then 
        rm -f /etc/localtime && ln -s /usr/share/zoneinfo/$TZ /etc/localtime
    fi
}

dir=(
    /etc/dirsrv
    /etc/fail2ban
    /etc/httpd
    /etc/my.cnf
    /etc/cyrus.conf
    /etc/imapd.conf
    /etc/imapd.annotations.conf
    /etc/kolab
    /etc/kolab-freebusy
    /etc/nginx
    /etc/opendkim
    /etc/opendkim.conf
    /etc/php-fpm.d
    /etc/php-fpm.conf
    /etc/php.d
    /etc/php.ini
    /etc/postfix
    /etc/roundcubemail
    /etc/sasldb2
    /etc/supervisord.conf
    /etc/clamd.conf
    /etc/clamd.d
    /etc/freshclam.conf
    /etc/iRony
    /etc/ssl
    /etc/mailname
    /etc/mail
    /etc/pki
    /var/lib/mysql
    /var/lib/dirsrv
    /var/lib/imap
    /var/lib/nginx
    /var/lib/spamassassin
    /var/lib/clamav
    /var/spool/amavisd
    /var/spool/imap
    /var/spool/mail
    /var/spool/postfix
    /var/spool/opendkim
    /var/spool/pykolab
    /var/log/chwala
    /var/log/clamav
    /var/log/dirsrv
    /var/log/httpd
    /var/log/iRony
    /var/log/kolab
    /var/log/kolab-freebusy
    /var/log/kolab-syncroton
    /var/log/kolab-webadmin
    /var/log/maillog
    /var/log/messages
    /var/log/mysqld.log
    /var/log/nginx
    /var/log/php-fpm
    /var/log/roundcubemail
    /var/log/supervisor
)


move_dirs()
{
    echo "info:  start moving lib and log folders to /data volume"

    for i in "${dir[@]}"; do mkdir -p /data$(dirname $i) ; done
    for i in "${dir[@]}"; do mv $i /data$i; done

    echo "info:  finished moving lib and log folders to /data volume"
}

link_dirs()
{
    echo "info:  start linking default lib and log folders to /data volume"

    for i in "${dir[@]}"; do rm -rf $i && ln -s /data$i $i ; done
 
    #Need for dirsrv
    mkdir /var/lock/dirsrv/slapd-$(hostname -s)/
    chown dirsrv: /var/run/dirsrv /var/lock/dirsrv/slapd-$(hostname -s)/

    echo "info:  finished linking default lib and log folders to /data volume"
}

configure_kolab()
{
    if [ ! -d /etc/dirsrv/slapd-* ] ; then 
        echo "info:  start configuring Kolab"

        chk_var  LDAP_ADMIN_PASS
        chk_var  LDAP_MANAGER_PASS
        chk_var  LDAP_CYRUS_PASS
        chk_var  LDAP_KOLAB_PASS
        chk_var  MYSQL_ROOT_PASS
        chk_var  MYSQL_KOLAB_PASS
        chk_var  MYSQL_ROUNDCUBE_PASS

        #Fix apache symlinks
        rm -f /etc/httpd/modules && ln -s /usr/lib64/httpd/modules /etc/httpd/modules
        rm -f /etc/httpd/logs && ln -s /var/log/httpd /etc/httpd/logs
        rm -f /etc/httpd/run && ln -s /var/run /etc/httpd/run

        expect <<EOF
spawn   setup-kolab --fqdn=$(hostname -f) --timezone=$TZ
set timeout 300
expect  "Administrator password *:"
send    "$LDAP_ADMIN_PASS\r"
expect  "Confirm Administrator password:"
send    "$LDAP_ADMIN_PASS\r"
expect  "Directory Manager password *:"
send    "$LDAP_MANAGER_PASS\r"
expect  "Confirm Directory Manager password:"
send    "$LDAP_MANAGER_PASS\r"
expect  "User *:"
send    "dirsrv\r"
expect  "Group *:"
send    "dirsrv\r"
expect  "Please confirm this is the appropriate domain name space"
send    "yes\r"
expect  "The standard root dn we composed for you follows"
send    "yes\r"
expect  "Cyrus Administrator password *:"
send    "$LDAP_CYRUS_PASS\r"
expect  "Confirm Cyrus Administrator password:"
send    "$LDAP_CYRUS_PASS\r"
expect  "Kolab Service password *:"
send    "$LDAP_KOLAB_PASS\r"
expect  "Confirm Kolab Service password:"
send    "$LDAP_KOLAB_PASS\r"
expect  "What MySQL server are we setting up"
send    "2\r"
expect  "MySQL root password *:"
send    "$MYSQL_ROOT_PASS\r"
expect  "Confirm MySQL root password:"
send    "$MYSQL_ROOT_PASS\r"
expect  "MySQL kolab password *:"
send    "$MYSQL_KOLAB_PASS\r"
expect  "Confirm MySQL kolab password:"
send    "$MYSQL_KOLAB_PASS\r"
expect  "MySQL roundcube password *:"
send    "$MYSQL_ROUNDCUBE_PASS\r"
expect  "Confirm MySQL roundcube password:"
send    "$MYSQL_ROUNDCUBE_PASS\r"
expect  "Starting kolabd:"
exit    0
EOF

        # Redirect to /webmail/ in apache
        sed -i 's/^\(DocumentRoot \).*/\1"\/usr\/share\/roundcubemail\/public_html"/' /etc/httpd/conf/httpd.conf

        #fix: Certificates changed by default from localhost.pem to key and crt
        postconf -e smtpd_tls_key_file=/etc/pki/tls/private/localhost.key
        postconf -e smtpd_tls_cert_file=/etc/pki/tls/certs/localhost.crt

        echo "info:  finished configuring Kolab"
    else
        echo "warn: Kolab already configured, skipping..."
    fi

}

configure_nginx()
{
    if [ "$(grep -c "^[^;]*nginx" /etc/supervisord.conf)" == "0" ] ; then
        echo "info:  start configuring nginx"

        sed -i '/^\[kolab_wap\]/,/^\[/ { x; /^$/ !{ x; H }; /^$/ { x; h; }; d; }; x; /^\[kolab_wap\]/ { s/\(\n\+[^\n]*\)$/\napi_url = https:\/\/'$(hostname -f)'\/kolab-webadmin\/api\1/; p; x; p; x; d }; x' /etc/kolab/kolab.conf

        sed -i "s/\$config\['assets_path'\] = '.*';/\$config\['assets_path'\] = '\/assets\/';/g" /etc/roundcubemail/config.inc.php

        # Comment apache
        sed -i --follow-symlinks '/^[^;]*httpd/s/^/;/' /etc/supervisord.conf
        # Uncoment nginx and php-fpm
        sed -i --follow-symlinks '/^;.*nginx/s/^;//' /etc/supervisord.conf
        sed -i --follow-symlinks '/^;.*php-fpm/s/^;//' /etc/supervisord.conf

        sed -i -e "/server_name /c\    server_name $(hostname -f);" /etc/nginx/conf.d/default.conf

        echo "info:  finished configuring nginx"
    else
        echo "warn:  nginx already configured, skipping..."
    fi
}

configure_nginx_cache()
{
    if [[ $(grep -c open_file_cache /etc/nginx/nginx.conf) == 0 ]] ; then
        echo "info:  start configuring nginx cacheing"

        #Adding open file cache to nginx
        sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
        a \    open_file_cache max=16384 inactive=5m;
        a \    open_file_cache_valid 90s; 
        a \    open_file_cache_min_uses 2;
        a \    open_file_cache_errors on;
        }' /etc/nginx/nginx.conf

        sed -i '/include \/etc\/nginx\/conf\.d\/\*.conf;/{
        a \    fastcgi_cache_key "$scheme$request_method$host$request_uri";
        a \    fastcgi_cache_use_stale error timeout invalid_header http_500;
        a \    fastcgi_cache_valid 200 302 304 10m;
        a \    fastcgi_cache_valid 301 1h; 
        a \    fastcgi_cache_min_uses 2; 
        }' /etc/nginx/nginx.conf

        sed -i '1ifastcgi_cache_path /var/lib/nginx/fastcgi/ levels=1:2 keys_zone=key-zone-name:16m max_size=256m inactive=1d;' /etc/nginx/conf.d/default.conf

        sed -i '/error_log/a \    fastcgi_cache key-zone-name;' /etc/nginx/conf.d/default.conf

        echo "info:  finished configuring nginx caching"
    else
        echo "warn:  nginx cacheing already configured, skipping..."
    fi
}

configure_spam_sieve()
{
    if [[ $(grep -c \$final_spam_destiny.*D_PASS /etc/amavisd/amavisd.conf) == 0 ]] ; then
        echo "info:  start configuring amavis"
        
        sed -i '/^[^#]*$sa_spam_subject_tag/s/^/#/' /etc/amavisd/amavisd.conf
        sed -i 's/^\($final_spam_destiny.*= \).*/\1D_PASS;/' /etc/amavisd/amavisd.conf

        # Uncoment set_default_sieve
        sed -i --follow-symlinks '/^;.*set_default_sieve/s/^;//' /etc/supervisord.conf

        # Set domain name
        sed -r -i "s/^\\\$mydomain = '[^']*';/\\\$mydomain = '$(hostname -d)';/" /etc/amavisd/amavisd.conf

        echo "info:  finished configuring amavis"
    else
        echo "warn:  amavis already configured, skipping..."
    fi

    if [[ $(grep -c \"X-Spam\" /var/lib/imap/sieve/global/default.script) == 0 ]] ; then
        echo "info:  start configuring spam sieve"
 
        # Create default sieve script
        mkdir -p /var/lib/imap/sieve/global/
        cat > /var/lib/imap/sieve/global/default.script << EOF
require "fileinto";
if header :contains "X-Spam-Flag" "YES"
{
        fileinto "Spam";
}
if header :contains "X-Spam" "yes"
{
        fileinto "Spam";
}
EOF
        # Compile it
        /usr/lib/cyrus-imapd/sievec /var/lib/imap/sieve/global/default.script /var/lib/imap/sieve/global/default.bc
    
        echo "info:  finished configuring spam sieve"
    else
        echo "warn:  spam sieve already configured, skipping..."
    fi
}

configure_certs()
{
    if [ `find $CERT_PATH -prune -empty` ] ; then
        echo "warn:  no certificates found in $CERT_PATH fallback to /etc/pki/tls/kolab"
        export CERT_PATH="/etc/pki/tls/kolab"
        domain_cers=${CERT_PATH}/$(hostname -f)
    else
        domain_cers=`echo ${CERT_PATH}/* | awk '{print $1}'`
    fi

    certificate_path=${domain_cers}/cert.pem
    privkey_path=${domain_cers}/privkey.pem
    chain_path=${domain_cers}/chain.pem
    fullchain_path=${domain_cers}/fullchain.pem

    if [ ! -f "$certificate_path" ] || [ ! -f "$privkey_path" ] ; then
        echo "info:  start generating certificate"
        mkdir -p ${domain_cers}

        # Generate key and certificate
        openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
                    -subj "/CN=$(hostname -f)" \
                    -keyout $privkey_path \
                    -out $certificate_path
    
        # Set access rights
        chown -R root:mail ${domain_cers}
        chmod 750 ${domain_cers}
        chmod 640 ${domain_cers}/*

        echo "info:  generating certificate finished"
    fi
    
    # Configure apache for SSL
    sed -i -e "/[^#]SSLCertificateFile /c\SSLCertificateFile $certificate_path" /etc/httpd/conf.d/ssl.conf
    sed -i -e "/[^#]SSLCertificateKeyFile /c\SSLCertificateKeyFile $privkey_path" /etc/httpd/conf.d/ssl.conf
    if [ -f "$chain_path" ]; then
        if `sed 's/#.*$//g' /etc/httpd/conf.d/ssl.conf | grep -q SSLCertificateChainFile` ; then
            sed -e "/[^#]*SSLCertificateChainFile: /cSSLCertificateChainFile: $chain_path" /etc/httpd/conf.d/ssl.conf
        else
            sed -i -e "/[^#]*SSLCertificateFile/aSSLCertificateChainFile: $chain_path" /etc/httpd/conf.d/ssl.conf 
        fi
    else
        sed -i -e "/SSLCertificateChainFile/d" /etc/httpd/conf.d/ssl.conf
    fi
    
    # Configuration nginx for SSL
    if [ -f "$fullchain_path" ]; then
        sed -i -e "/ssl_certificate /c\    ssl_certificate $fullchain_path;" /etc/nginx/conf.d/default.conf
    else
        sed -i -e "/ssl_certificate /c\    ssl_certificate $certificate_path;" /etc/nginx/conf.d/default.conf
    fi
    sed -i -e "/ssl_certificate_key/c\    ssl_certificate_key $privkey_path;" /etc/nginx/conf.d/default.conf
    
    #Configure Cyrus for SSL
    sed -r -i --follow-symlinks \
        -e "s|^tls_server_cert:.*|tls_server_cert: $certificate_path|g" \
        -e "s|^tls_server_key:.*|tls_server_key: $privkey_path|g" \
        /etc/imapd.conf

    if [ -f "$chain_path" ]; then
        if grep -q tls_server_ca_file /etc/imapd.conf ; then
            sed -i --follow-symlinks -e "s|^tls_server_ca_file:.*|tls_server_ca_file: $chain_path|g" /etc/imapd.conf
        else
            sed -i --follow-symlinks -e "/tls_server_cert/atls_server_ca_file: $chain_path" /etc/imapd.conf
        fi
    else
        sed -i --follow-symlinks -e "/^tls_server_ca_file/d" /etc/httpd/conf.d/ssl.conf
    fi
        
    #Configure Postfix for SSL
    postconf -e smtpd_tls_key_file=$privkey_path
    postconf -e smtpd_tls_cert_file=$certificate_path
    if [ -f "$chain_path" ]; then
        postconf -e smtpd_tls_CAfile=$chain_path
    else
        postconf -e smtpd_tls_CAfile=
    fi

}
 
configure_force_https()
{
    if [ "$(grep -c 'RewriteRule ^(.*)$ https://%{HTTP_HOST}' /etc/httpd/conf/httpd.conf)" == "0" ] ; then
    echo "info:  start configuring force https"

    cat >> /etc/httpd/conf/httpd.conf << EOF

<VirtualHost _default_:80>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
</VirtualHost>
EOF

    #sed -i -z 's|include /etc/nginx/kolab.conf;|location / {\n        return 301 https://$server_name$request_uri;\n    }|' /etc/nginx/conf.d/default.conf
    sed -i -e '10s|include /etc/nginx/kolab.conf;|location / {\n        return 301 https://$server_name$request_uri;\n    }|' /etc/nginx/conf.d/default.conf

    echo "info:  finished configuring force https"
    else
        echo "warn:  force https already configured, skipping..."
    fi

    echo "info:  start configuring SSL"
    #Configure kolab-cli for SSL
    sed -r -i \
          -e '/api_url/d' \
          -e "s#\[kolab_wap\]#[kolab_wap]\napi_url = https://$(hostname -f)/kolab-webadmin/api#g" \
          /etc/kolab/kolab.conf
    
    #Configure Roundcube for SSL
    sed -i -e 's/http:/https:/' /etc/roundcubemail/libkolab.inc.php
    sed -i -e 's/http:/https:/' /etc/roundcubemail/kolab_files.inc.php
    sed -i -e '/^?>/d' /etc/roundcubemail/config.inc.php
        
    # Tell the webclient the SSL iRony URLs for CalDAV and CardDAV
    if [ "$(grep -c "calendar_caldav_url" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
    cat >> /etc/roundcubemail/config.inc.php << EOF
# caldav/webdav
\$config['calendar_caldav_url']             = "https://%h/iRony/calendars/%u/%i";
\$config['kolab_addressbook_carddav_url']   = 'https://%h/iRony/addressbooks/%u/%i';
EOF
    fi

    if [ "$(grep -c "force_https" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
    # Redirect all http traffic to https
    cat >> /etc/roundcubemail/config.inc.php << EOF
# Force https redirect for http requests
\$config['force_https'] = true;
EOF
    fi

    echo "info:  finished configuring SSL"
}

configure_fail2ban()
{
    if [ "$(grep -c "^[^;]*fail2ban" /etc/supervisord.conf)" == "0" ] ; then
        echo "info:  start configuring Fail2ban"

        touch /var/log/kolab-syncroton/userlogins
        touch /var/log/chwala/userlogins
        touch /var/log/iRony/userlogins

        # Uncoment fail2ban
        sed -i --follow-symlinks '/^;.*fail2ban/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring Fail2ban"
    else
        echo "warn:  Fail2ban already configured, skipping..."
    fi
}

configure_dkim()
{
    if [ "$(grep -c -ve "^#\|^[[:space:]]*$"  /etc/opendkim/KeyTable )" == "0" ] ; then
        echo "info:  start configuring OpenDKIM"

        opendkim-genkey -D /etc/opendkim/keys/ -d $(hostname -d) -s $(hostname -s)
        
        chgrp opendkim /etc/opendkim/keys/*
        chmod g+r /etc/opendkim/keys/*
    
        sed -i "/^127\.0\.0\.1\:[10025|10027].*smtpd/a \    -o receive_override_options=no_milters" /etc/postfix/master.cf
    
        sed -i --follow-symlinks 's/^\(^Mode\).*/\1  sv/' /etc/opendkim.conf

        cat >> /etc/opendkim.conf  <<EOF
KeyTable      /etc/opendkim/KeyTable
SigningTable  /etc/opendkim/SigningTable
X-Header yes 
EOF

        echo $(hostname -f | sed s/\\./._domainkey./) $(hostname -d):$(hostname -s):$(ls /etc/opendkim/keys/*.private) | cat >> /etc/opendkim/KeyTable
        echo $(hostname -d) $(echo $(hostname -f) | sed s/\\./._domainkey./) | cat >> /etc/opendkim/SigningTable

        postconf -e milter_default_action=accept
        postconf -e milter_protocol=2
        postconf -e smtpd_milters=inet:localhost:8891
        postconf -e non_smtpd_milters=inet:localhost:8891
    
        # Uncoment opendkim
        sed -i --follow-symlinks '/^;.*opendkim/s/^;//' /etc/supervisord.conf

        echo "info:  finished configuring OpenDKIM"
    else
        echo "warn:  OpenDKIM already configured, skipping..."
    fi
}

kolab_rcpt_policy_off()
{
    if [ "$(grep -c "daemon_rcpt_policy = False" /etc/kolab/kolab.conf)" == "0" ] ; then

        echo "info:  start disabling recipient policy"
        if [ "$(grep -c "daemon_rcpt_policy" /etc/kolab/kolab.conf)" == "0" ] ; then
            sed -i -e '/\[kolab\]/a\daemon_rcpt_policy = False' /etc/kolab/kolab.conf
        else
            sed -i -e '/daemon_rcpt_policy/c\daemon_rcpt_policy = False' /etc/kolab/kolab.conf
        fi
        echo "info:  finished disabling recipient policy"
    fi
}

kolab_default_locale()
{
    echo "info:  start configuring kolab default locale"
    sed -i -e '/default_locale/c\default_locale = '$KOLAB_DEFAULT_LOCALE /etc/kolab/kolab.conf
    echo "info:  finished configuring kolab default locale"
}

configure_size()
{
    echo "info:  start configuring sizes"
    sed -i --follow-symlinks -e '/memory_limit/c\memory_limit = '$MAX_MEMORY_SIZE /etc/php.ini
    sed -i --follow-symlinks -e '/upload_max_filesize/c\upload_max_filesize = '$MAX_FILE_SIZE /etc/php.ini
    sed -i --follow-symlinks -e '/post_max_size/c\post_max_size = '$MAX_MAIL_SIZE /etc/php.ini
    #sed -i -e '/php_value post_max_size/c\php_value post_max_size             '$MAX_MAIL_SIZE /usr/share/chwala/public_html/.htaccess           
    #sed -i -e '/php_value upload_max_filesize/c\php_value upload_max_filesize             '$MAX_FILE_SIZE /usr/share/chwala/public_html/.htaccess
    sed -i -e '/client_max_body_size/c\        client_max_body_size '$MAX_BODY_SIZE';' /etc/nginx/conf.d/default.conf 

    # Convert megabytes to bytes for postfix
    if [[ $MAX_MAIL_SIZE == *"M" ]] ;  then MAX_MAIL_SIZE=$[($(echo $MAX_MAIL_SIZE | sed 's/[^0-9]//g'))*1024*1024] ; fi
    if [[ $MAX_MAILBOX_SIZE == *"M" ]] ;  then MAX_MAILBOX_SIZE=$[($(echo $MAX_MAILBOX_SIZE | sed 's/[^0-9]//g'))*1024*1024] ; fi
    postconf -e message_size_limit=$MAX_MAIL_SIZE    
    postconf -e mailbox_size_limit=$MAX_MAILBOX_SIZE
    echo "info:  finished configuring sizes"
}

roundcube_skin()
{
    echo "info:  start configuring roundcube skin"
    sed -i -r "s/^\\s*(\\\$config\\[['\"]skin['\"]\\])\\s*=[^;]*;/\\1 = '${ROUNDCUBE_SKIN}';/g" /etc/roundcubemail/config.inc.php
    echo "info:  finished configuring roundcube skin"
}

roundcube_zipdownload()
{
    if [ "$(grep -c "zipdownload" /etc/roundcubemail/config.inc.php)" == "0" ] ; then
        echo "info:  start configuring zipdownload plugin"
        sed -i "/'contextmenu',/a \            'zipdownload'," /etc/roundcubemail/config.inc.php
        echo "info:  finished configuring zipdownload plugin"
    else
        echo "warn:  zipdownload plugin already configured, skipping..."
    fi
}

roundcube_trash_folder()
{
    echo "info:  start configuring trash folder istead flaging"
    sed -i "s/\$config\['skip_deleted'\] = '.*';/\$config\['skip_deleted'\] = 'false';/g" /etc/roundcubemail/config.inc.php
    sed -i "s/\$config\['flag_for_deletion'\] = '.*';/\$config\['flag_for_deletion'\] = 'false';/g" /etc/roundcubemail/config.inc.php
    echo "info:  finished configuring trash folder istead flaging"
}

postfix_milter()
{
    if [ "$(grep "smtpd_milters" /etc/postfix/main.cf | grep -cv localhost)" == "0" ] ; then

        echo "info:  start configuring another milter"
    
        #Reconfigure OpenDKIM
        if [ "$(postconf smtpd_milters | grep -c inet:localhost:8891)" != "0" ] && [ "$(grep -c "smtpd_milters=inet:localhost:8891" /etc/postfix/master.cf)" == "0" ] ; then
            sed -i "/^127\.0\.0\.1\:10027.*smtpd/a \    -o smtpd_milters=inet:localhost:8891" /etc/postfix/master.cf
            sed -i "/^127\.0\.0\.1\:10027.*smtpd/a \    -o milter_protocol=2" /etc/postfix/master.cf
        fi
    
        postconf -e milter_protocol=$EXT_MILTER_PROTO
        postconf -e smtpd_milters=$EXT_MILTER_ADDR
        postconf -e non_smtpd_milters=$EXT_MILTER_ADDR
        postconf -e content_filter=smtp-wallace:[127.0.0.1]:10026
        
        #Disable amavis
        awk '/smtp-amavis/{f=1} !NF{f=0} f{$0="#" $0} 1' /etc/postfix/master.cf > /tmp/master.cf.tmp
        awk '/127.0.0.1:10025/{f=1} !NF{f=0} f{$0="#" $0} 1' /tmp/master.cf.tmp > /etc/postfix/master.cf
        rm -f /tmp/master.cf.tmp
    
        sed -i '/^[^#].*receive_override_options=no_milters/d' /etc/postfix/master.cf
    
        # Comment amavis and clamd
        sed -i --follow-symlinks '/^[^;]*amavisd/s/^/;/' /etc/supervisord.conf
        sed -i --follow-symlinks '/^[^;]*clamd/s/^/;/' /etc/supervisord.conf
    
        echo "info:  finished configuring another milter"
    fi
}

services=(
        'kolab-saslauthd'
        'wallace'
        'amavisd'
        'postfix'
        'opendkim'
        'dirsrv'
        'php-fpm'
        'nginx'
        'clamd'
        'kolabd'
        'mysqld'
        'fail2ban'
        'rsyslog'
        'cyrus-imapd'
)

stop_services()
{
    echo "info:  stopping services"

	service httpd stop
	kill -9 $(pidof httpd)
	
	for (( idx=${#services[@]}-1 ; idx>=0 ; idx-- )) ; do
		echo "Stopping service ${services[idx]}..."
		service ${services[idx]} stop
	done

    echo "info:  finished stopping services"
}

start_services()
{
    echo "info:  Starting services"

	for i in "${services[@]}"
	do
        echo "Starting service ${i}..."
        service "${i}" start 
	done
	
	tail -f /var/log/maillog
}

[ -d /data/etc/dirsrv/slapd-* ] || export FIRST_SETUP=true #Check for first setup

                                           load_defaults
                                           set_timezone
[ "$FIRST_SETUP" = true  ]              && move_dirs
                                           link_dirs
[ "$FIRST_SETUP" = true ]               && configure_kolab

[ "$WEBSERVER" = "nginx" ]              && configure_nginx
[ "$NGINX_CACHE" = true ]               && configure_nginx_cache
[ "$SPAM_SIEVE" = true ]                && configure_spam_sieve
                                           configure_certs
[ "$FORCE_HTTPS" = true ]               && configure_force_https
[ "$FAIL2BAN" = true ]                  && configure_fail2ban
[ "$DKIM" = true ]                      && configure_dkim
[ "$KOLAB_RCPT_POLICY" = false ]        && kolab_rcpt_policy_off
[ ! -z "$KOLAB_DEFAULT_LOCALE" ]        && kolab_default_locale
                                           configure_size
[ ! -z "$ROUNDCUBE_SKIN" ]              && roundcube_skin
[ "$ROUNDCUBE_ZIPDOWNLOAD" = true ]     && roundcube_zipdownload
[ "$ROUNDCUBE_TRASH" = true ]           && roundcube_trash_folder
[ ! -z "$EXT_MILTER_ADDR" ]             && postfix_milter
[ "$FIRST_SETUP" = true ]               && stop_services
trap "{ stop_services ; exit 0; }" EXIT
                                           start_services
