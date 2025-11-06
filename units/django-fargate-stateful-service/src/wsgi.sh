#!/bin/bash
set -e

echo "[INFO] Starting Django application..."

# Run database migrations
echo "[INFO] Running database migrations..."
python manage.py migrate --noinput

# Collect static files
echo "[INFO] Collecting static files..."
python manage.py collectstatic --noinput --clear

# Start Gunicorn
echo "[INFO] Starting Gunicorn server..."
exec gunicorn config.wsgi:application \
    --config gunicorn.conf.py \
    --log-file - \
    --access-logfile - \
    --error-logfile -
