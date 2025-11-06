"""Development settings"""
from .base import *

DEBUG = True
ALLOWED_HOSTS = ['*']

# Development tools
INSTALLED_APPS += [
    'django_extensions',
]

# Disable security features for local development
SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# CORS - Allow all origins in development
CORS_ALLOW_ALL_ORIGINS = True
