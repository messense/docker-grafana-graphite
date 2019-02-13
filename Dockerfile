FROM     ubuntu:16.04

# ---------------- #
#   Installation   #
# ---------------- #

ENV DEBIAN_FRONTEND noninteractive

# Install all prerequisites
RUN     apt-get -y update
RUN     apt-get -y install software-properties-common curl
RUN     curl -sL https://deb.nodesource.com/setup_6.x | bash
RUN     apt-get -y update
RUN     apt-get -y install python-ldap libcairo2-dev python-pysqlite2 libffi-dev \
                           python-pip supervisor nginx-light nodejs git wget build-essential python-dev

RUN     pip install -U pip pytz gunicorn
RUN     npm install ini chokidar

# Checkout the stable branches of Graphite, Carbon and Whisper and install from there
RUN     mkdir /src
RUN     git clone https://github.com/graphite-project/whisper.git /src/whisper            &&\
        cd /src/whisper                                                                   &&\
        git checkout 1.0.x                                                                &&\
        pip install . && \
        python setup.py install

RUN     git clone https://github.com/graphite-project/carbon.git /src/carbon              &&\
        cd /src/carbon                                                                    &&\
        git checkout 1.0.x                                                                &&\
        pip install . && \
        python setup.py install


RUN     git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web  &&\
        cd /src/graphite-web                                                              &&\
        git checkout 1.0.x                                                                &&\
        pip install .  && \
        python setup.py install && \
        python check-dependencies.py

# Install StatsD
RUN     git clone https://github.com/etsy/statsd.git /src/statsd                                                                        &&\
        cd /src/statsd                                                                                                                  &&\
        git checkout v0.8.0


# Install Grafana
RUN     mkdir /src/grafana                                                                                                    &&\
        mkdir /opt/grafana                                                                                                    &&\
        wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-5.4.3.linux-x64.tar.gz -O /src/grafana.tar.gz      &&\
        tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1                                                     &&\
        rm /src/grafana.tar.gz                                                                                                &&\
        ln -s /opt/grafana/bin/grafana-cli /usr/local/bin/grafana-cli                                                         &&\
        mkdir -p /var/lib/grafana                                                                                             &&\
        ln -s /opt/grafana/data/plugins /var/lib/grafana/plugins


# ----------------- #
#   Configuration   #
# ----------------- #

# Confiure StatsD
ADD     ./statsd/config.js /src/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /opt/graphite/storage/whisper
RUN     touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index
RUN     chown -R www-data /opt/graphite/storage
RUN     chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper
RUN     chmod 0664 /opt/graphite/storage/graphite.db
RUN     cp /src/graphite-web/webapp/manage.py /opt/graphite/webapp
RUN     cd /opt/graphite/webapp/ && python manage.py migrate --run-syncdb --noinput

# Configure Grafana
ADD     ./grafana/custom.ini /opt/grafana/conf/custom.ini

# Add the default dashboards
RUN     mkdir /src/dashboards

# Configure nginx and supervisord
ADD     ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD     ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80

# StatsD UDP port
EXPOSE  8125/udp

# StatsD Management port
EXPOSE  8126

# Graphite web port
EXPOSE 81

# Graphite Carbon port
EXPOSE 2003


# -------- #
#   Run!   #
# -------- #

CMD     ["/usr/bin/supervisord"]
