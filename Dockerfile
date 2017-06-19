FROM centos:centos6
MAINTAINER kvaps <kvapss@gmail.com>
ENV REFRESHED_AT 2016-02-05

RUN yum -y update \
 && yum -y install epel-release \
 && yum -y install http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm \
 && curl -o /etc/yum.repos.d/Kolab:3.4.repo http://obs.kolabsys.com/repositories/Kolab:/3.4/CentOS_6/Kolab:3.4.repo \
 && curl -o /etc/yum.repos.d/Kolab:3.4:Updates.repo http://obs.kolabsys.com/repositories/Kolab:/3.4:/Updates/CentOS_6/Kolab:3.4:Updates.repo

RUN gpg --keyserver pgp.mit.edu --recv-key 0x446D5A45 \
 && gpg --export --armor devel@lists.kolab.org > devel.asc \
 && rpm --import devel.asc \
 && rm devel.asc

# Also install docfiles as they contain important files for the setup-kolab script
RUN sed -i '/nodocs/d' /etc/yum.conf

# Install kolab
RUN yum -y install kolab

# Install additional soft
RUN yum -y install expect mod_ssl nginx php-fpm opendkim fail2ban git php-devel zlib-devel gcc pcre-devel dhclient

#Update php-zlib
RUN pecl install zip

#Install zipdownload
RUN git clone https://github.com/roundcube/roundcubemail/ -b release-1.1 --depth 1 /tmp/roundcube \
 && mv /tmp/roundcube/plugins/zipdownload/ /usr/share/roundcubemail/plugins/ \
 && rm -rf /tmp/roundcube/

#User for 389-ds
RUN adduser dirsrv

# fix bug: "unable to open Berkeley db /etc/sasldb2: No such file or directory"
RUN echo password | saslpasswd2 sasldb2 && chown cyrus:saslauth /etc/sasldb2

# fix: http://trac.roundcube.net/ticket/1490424
RUN sed -i "840s/\$this/\$me/g"  /usr/share/roundcubemail/program/lib/Roundcube/rcube_ldap.php 

# fix permissions for amavis and clam
RUN sed -i 's|"/var/spool/amavisd/clamd.sock"|"127.0.0.1:3310"|' /etc/amavisd/amavisd.conf \
 && usermod -a -G clam -G amavis clam \
 && usermod -a -G clam -G amavis amavis

# Add config and setup script, run it
ADD set_spam_sieve.sh /bin/set_spam_sieve.sh
ADD configs/nginx/letsencrypt.conf /etc/nginx/letsencrypt.conf
ADD configs/nginx/kolab.conf /etc/nginx/kolab.conf
ADD configs/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
RUN rm -f /etc/php-fpm.d/www.conf
ADD configs/php-fpm.d/* /etc/php-fpm.d/
ADD configs/fail2ban/jail.conf /etc/fail2ban/jail.conf
ADD configs/fail2ban/filter.d/* /etc/fail2ban/filter.d/
ADD start.sh /bin/start.sh

# Ports: HTTP HTTPS SMTP SMTPS POP3 POP3S IMAP IMAPS SIEVE LDAPS
EXPOSE  80 443 25 587 143 993 110 995 4190 636
VOLUME ["/data"]
ENTRYPOINT ["/bin/start.sh"]

