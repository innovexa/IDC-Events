#!/usr/bin/env bash

cat > /etc/uwsgi.ini <<'EOF'
[uwsgi]
uid = indico
gid = apache
umask = 027
pidfile = /run/uwsgi/uwsgi.pid

processes = 4
enable-threads = true
socket = 127.0.0.1:8008
stats = /opt/indico/uwsgi-stats.sock
protocol = uwsgi

master = true
auto-procname = true
procname-prefix-spaced = indico
disable-logging = true

plugin = python
single-interpreter = true

touch-reload = /opt/indico/indico.wsgi
wsgi-file = /opt/indico/indico.wsgi
virtualenv = /opt/indico/.venv

vacuum = true
buffer-size = 20480
memory-report = true
max-requests = 2500
harakiri = 900
harakiri-verbose = true
reload-on-rss = 2048
evil-reload-on-rss = 8192
EOF

cat > /etc/httpd/conf.d/indico.conf <<'EOF'
<VirtualHost *:80>
    ServerName $SERVER_NAME
    DocumentRoot "/var/empty/apache"

    XSendFile on
    XSendFilePath /opt/indico
    CustomLog /opt/indico/log/apache/access.log combined
    ErrorLog /opt/indico/log/apache/error.log
    LogLevel error
    ServerSignature Off

    AliasMatch "^/static/assets/(core|(?:plugin|theme)-[^/]+)/(.*)$" "/opt/indico/static/assets/$1/$2"
    AliasMatch "^/(css|images|js|static(?!/plugins|/assets|/themes|/custom))(/.*)$" "/opt/indico/static/htdocs/$1$2"
    Alias /robots.txt /opt/indico/static/htdocs/robots.txt

    SetEnv UWSGI_SCHEME http
    ProxyPass / uwsgi://127.0.0.1:8008/

    <Directory /opt/indico>
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

echo 'LoadModule proxy_uwsgi_module modules/mod_proxy_uwsgi.so' > /etc/httpd/conf.modules.d/proxy_uwsgi.conf

cat > /etc/systemd/system/indico-celery.service <<'EOF'
[Unit]
Description=Indico Celery
After=network.target

[Service]
ExecStart=/opt/indico/.venv/bin/indico celery worker -B
Restart=always
SyslogIdentifier=indico-celery
User=indico
Group=apache
UMask=0027
Type=simple
KillMode=mixed
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

chown -R indico:apache /opt/indico/
chown indico:apache /opt/indico/etc/indico.conf

su indico <<'EOF'
virtualenv ~/.venv
source ~/.venv/bin/activate
pip install -U pip setuptools
pip install /opt/indico/*.whl
indico setup create_symlinks /opt/indico
indico setup create_logging_config /opt/indico

cp -rL /opt/indico/htdocs /opt/indico/static/
mkdir -p /opt/indico/tmp
mkdir -p /opt/indico/static/assets
mkdir -p /opt/indico/cache

mkdir -p ~/log/apache
chmod go-rwx ~/* ~/.[^.]*
chmod 710 ~/ ~/archive ~/assets ~/cache ~/log ~/tmp
chmod 750 ~/web ~/.venv
chmod g+w ~/log/apache
echo -e "\nSTATIC_FILE_METHOD = 'xsendfile'" >> ~/etc/indico.conf
EOF

echo 'Running Indico'
sh ./run_indico.sh &

echo 'Running Celery'
sh ./run_celery.sh &

httpd -DFOREGROUND
