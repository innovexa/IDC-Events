FROM centos:latest

ENV INDICO_VIRTUALENV="/opt/indico/.venv/bin" INDICO_CONFIG="/opt/indico/etc/indico.conf"

ARG pip="${INDICO_VIRTUALENV}/pip"

RUN yum install -y epel-release \
    yum update && yum install -y httpd mod_proxy_uwsgi mod_ssl mod_xsendfile \
    yum install -y gcc uwsgi uwsgi-plugin-python \
    yum install -y python-devel python-virtualenv libjpeg-turbo-devel libxslt-devel libxml2-devel libffi-devel pcre-devel libyaml-devel

RUN useradd -rm -g apache -d /opt/indico -s /bin/bash indico

COPY src/dist /opt/indico

COPY scripts/indico.conf /opt/indico/etc/
COPY apache/httpd.conf /etc/httpd/conf/

COPY scripts/uwsgi.ini /etc/uwsgi.ini
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY scripts/run_celery.sh /run_celery.sh
COPY scripts/run_indico.sh /run_indico.sh

ENTRYPOINT ["/docker-entrypoint.sh"]