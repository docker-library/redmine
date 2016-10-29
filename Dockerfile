FROM ubuntu
MAINTAINER mwaeckerlin
ENV TERM xterm

EXPOSE 80
ENV DEFAULT_LANGUAGE en

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 libapache2-mod-passenger bundler
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y emacs-nox debconf-utils
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y redmine-mysql
RUN chown -R www-data:www-data /usr/share/redmine
RUN a2enmod passenger
RUN rm -r /var/www/html
RUN ln -s /usr/share/redmine/public /var/www/html
ADD redmine.conf /etc/apache2/conf-available/redmine.conf
RUN a2enconf redmine
ADD start.sh /start.sh
CMD /start.sh

VOLUME /var/lib/redmine
