#!/bin/bash

echo 'Starting Celery...'

su indico <<'EOF'
source ~/.venv/bin/activate
indico celery worker -B
EOF
