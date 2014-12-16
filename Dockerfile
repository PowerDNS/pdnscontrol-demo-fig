FROM debian:testing
RUN apt-get update
RUN apt-get dist-upgrade -y 
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install libpq-dev libmysqlclient-dev git python-virtualenv python-dev procps mysql-client tmux strace build-essential libpython-dev graphite-carbon graphite-web openssh-server libapache2-mod-wsgi apache2
ADD https://downloads.powerdns.com/releases/deb/pdns-static_3.4.0-1_amd64.deb /
RUN dpkg -i /pdns-static_3.4.0-1_amd64.deb
ADD https://downloads.powerdns.com/releases/deb/pdns-recursor_3.6.1-1_amd64.deb /
RUN dpkg -i /pdns-recursor_3.6.1-1_amd64.deb
ADD schema.mysql.sql .
RUN mkdir -p /opt
RUN useradd -d /opt/pdnscontrol -m --system pdnscontrol

RUN cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-available/graphite-web.conf
RUN a2ensite graphite-web
RUN a2dissite 000-default
RUN graphite-manage syncdb --noinput
RUN chown _graphite:_graphite /var/lib/graphite/graphite.db

USER pdnscontrol
#WORKDIR /opt/pdnscontrol  convert below to rely on this
RUN cd ~ && git clone https://github.com/PowerDNS/pdnscontrol.git && cd pdnscontrol && git checkout 7dcfdde6bbfad6e1616e5226598bdd69337cfb97
#WORKDIR /opt/pdnscontrol/pdnscontrol  and this
RUN cd ~/pdnscontrol && virtualenv venv-pdnscontrol
RUN cd ~/pdnscontrol && find ./venv-pdnscontrol/bin/
RUN cd ~/pdnscontrol && ./venv-pdnscontrol/bin/pip install -r requirements.txt
RUN cd ~/pdnscontrol && cat instance/pdnscontrol.conf.example
ADD ./pdnscontrol.sh /
USER root
