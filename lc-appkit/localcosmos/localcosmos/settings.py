"""
Django settings for localcosmos project.

Generated by 'django-admin startproject' using Django 5.0.4.

For more information on this file, see
https://docs.djangoproject.com/en/5.0/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/5.0/ref/settings/
"""

from pathlib import Path
import os, json
from django.utils.translation import gettext_lazy as _

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

ADMINS = json.loads(os.environ['ADMINS'])

SITE_ID = 1

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ['SECRET_KEY']

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', False) == 'True'

ALLOWED_HOSTS = json.loads(os.environ['ALLOWED_HOSTS'])

if DEBUG == True:
    ALLOWED_HOSTS = ['*']

# Application definition
SHARED_APPS = (
    'django_tenants',

    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.sites',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',

    # LC
    # 1st party
    'app_kit.multi_tenancy',
    'localcosmos_server',
    'localcosmos_server.app_admin',
    'localcosmos_server.server_control_panel',
    
    'taxonomy', # taxonomy itself does not provide any models - taxonomy.sources.* provide models
    'taxonomy.sources.col', # has its own db, but uses the public schema -> shared_apps
    'taxonomy.sources.algaebase', # has its own db, but uses the public schema -> shared_apps
    'app_kit.app_kit_api',
    
    'anycluster',

    # 3rd party
    # no models
    'django.forms',
    
    'rules',
    'el_pagination',
    'django_countries',
    'corsheaders',
    'rest_framework',
    'rest_framework.authtoken',
    'drf_spectacular',

    'octicons',

    'imagekit', 
    'django_cleanup.apps.CleanupConfig',
)

TENANT_APPS = (
    # The following Django contrib apps must be in TENANT_APPS (?)
    # It seems to be better to only have them in shared apps:
    # https://github.com/django-tenants/django-tenants/issues/290
    #'django.contrib.contenttypes',

    # 1st party
    'localcosmos_server.datasets',
    'localcosmos_server.template_content', # accessible via app_kit or app_admin
    'localcosmos_server.analytics',
    'app_kit',
    'app_kit.features.backbonetaxonomy',
    'app_kit.features.generic_forms',
    'app_kit.features.taxon_profiles',
    'app_kit.features.nature_guides',
    'app_kit.features.glossary',
    'app_kit.features.maps',
    'app_kit.features.frontend',
    
    'content_licencing',

    'taxonomy.sources.custom',

    'taggit',
)

INSTALLED_APPS = list(SHARED_APPS) + [app for app in TENANT_APPS if app not in SHARED_APPS]

FORM_RENDERER = 'django.forms.renderers.TemplatesSetting'

MIDDLEWARE = [
    'app_kit.multi_tenancy.middleware.LocalCosmosTenantMiddleware', # HAS TO BE ON TOP includes 'django_tenants.middleware.main.TenantMainMiddleware',
    'localcosmos_server.middleware.LocalCosmosServerSetupMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'app_kit.middleware.AppKitPermissionsMiddleware',
    'localcosmos_server.app_admin.middleware.AppAdminMiddleware',
    'localcosmos_server.server_control_panel.middleware.ServerControlPanelMiddleware',
]

STATICFILES_FINDERS = [
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
]

AUTHENTICATION_BACKENDS = (
    'rules.permissions.ObjectPermissionBackend',
    'django.contrib.auth.backends.ModelBackend',
)


TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        #'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'localcosmos_server.context_processors.localcosmos_server',
                'app_kit.context_processors.app_kit_context',
            ],
            'loaders' : [
                'django.template.loaders.filesystem.Loader',
                'django.template.loaders.app_directories.Loader',
            ]
        },
    },
]


WSGI_APPLICATION = 'localcosmos.wsgi.application'


# Database
# https://docs.djangoproject.com/en/5.0/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django_tenants.postgresql_backend',
        'NAME': os.environ['DB_NAME'],
        'USER' : os.environ['DB_USER'],
        'PASSWORD' : os.environ['DB_PASSWORD'],
        'HOST' : os.environ['DB_HOST'],
    },
    'taxonomy_db' : {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ['TAXONOMY_DB_NAME'],
        'USER': os.environ['TAXONOMY_DB_USER'],
        'PASSWORD': os.environ['TAXONOMY_DB_PASSWORD'],
        'HOST': os.environ['TAXONOMY_DB_HOST'],
    }
}

ORIGINAL_BACKEND = 'django.contrib.gis.db.backends.postgis'
DATABASE_ROUTERS = ['taxonomy.DBRouter.TaxonomyRouter', 'django_tenants.routers.TenantSyncRouter']

TAXONOMY_DATABASES = json.loads(os.environ.get('TAXONOMY_DATABASES', "[]")) + [('taxonomy.sources.custom', _('Custom Taxa'))]

# Nature guide should not appear as an selectable source
LAZY_TAXONOMY_SOURCES = TAXONOMY_DATABASES + [('app_kit.features.nature_guides', _('Nature Guide'))]

# Password validation
# https://docs.djangoproject.com/en/5.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True

LOCALE_PATHS = (
   os.path.join(BASE_DIR, 'locale'),
)

# LOGIN and LOGOUT
LOGIN_URL = '/server/log-in/'

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.0/howto/static-files/

STATIC_URL = '/static/'
STATIC_ROOT = '/var/www/localcosmos/static/'

MEDIA_ROOT = '/var/www/localcosmos/media/'
MEDIA_URL = '/media/'


# django-tenants
TENANT_MODEL = 'multi_tenancy.Tenant'
TENANT_DOMAIN_MODEL = 'multi_tenancy.Domain'

PUBLIC_SCHEMA_URLCONF = 'localcosmos.urls'
ROOT_URLCONF = 'app_kit.multi_tenancy.tenant_schema_urls'

# Default primary key field type
# https://docs.djangoproject.com/en/5.0/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# LOCAL COSMOS APP KIT
APP_KIT_LONG_NAME = os.environ['APP_KIT_LONG_NAME']
APP_KIT_SHORT_NAME = os.environ['APP_KIT_SHORT_NAME']
APP_KIT_API_PROTOCOL = 'https://'
APP_KIT_MAXIMUM_IMAGE_UPLOAD_SIZE = 5 * 1024 * 1024
APP_KIT_ROOT = '/opt/apps/'
APP_KIT_DOMAIN = os.environ['APP_KIT_DOMAIN']
APP_KIT_URL = 'app-kit/'
APP_KIT_SUPPORTED_PLATFORMS = json.loads(os.environ['APP_KIT_SUPPORTED_PLATFORMS'])
APP_KIT_TEMPORARY_FOLDER = '/opt/localcosmos/tmp/'
APP_KIT_PRIVATE_FRONTENDS_PATH = '/opt/localcosmos_frontends/'

APP_KIT_ENABLE_META_NODE_DESCRIPTION = os.environ.get('APP_KIT_ENABLE_META_NODE_DESCRIPTION', False) == 'True'
APP_KIT_LOAD_TRUNCATED_IMAGES = True
APP_KIT_ENABLE_TAXON_PROFILES_LONG_TEXTS = False

APP_KIT_APIUSER_USERNAME = os.environ['APP_KIT_APIUSER_USERNAME']
APP_KIT_APIUSER_PASSWORD = os.environ['APP_KIT_APIUSER_PASSWORD']
APP_KIT_APIUSER_EMAIL = os.environ['APP_KIT_APIUSER_EMAIL']

# APP KIT SANDBOX
APP_KIT_MODE = os.environ.get('APP_KIT_MODE', 'live')
APP_KIT_SANDBOX_USER = os.environ.get('APP_KIT_SANDBOX_USER', 'user')
APP_KIT_SANDBOX_PASSWORD = os.environ.get('APP_KIT_SANDBOX_PASSWORD', 'sandbox1234')

APP_KIT_DEFAULT_FRONTEND = 'Multiverse'

APP_KIT_ANDROID_KEYSTORE_PATH = os.environ['APP_KIT_ANDROID_KEYSTORE_PATH']
APP_KIT_ANDROID_KEYSTORE_PASS = os.environ['APP_KIT_ANDROID_KEYSTORE_PASS']
APP_KIT_ANDROID_KEY_PASS = os.environ['APP_KIT_ANDROID_KEY_PASS']

APP_KIT_LEGAL_NOTICE = json.loads(os.environ['APP_KIT_LEGAL_NOTICE'])

APP_KIT_STAGING_BASE_DOMAIN = os.environ['APP_KIT_STAGING_BASE_DOMAIN']

RESERVED_SUBDOMAINS = ['public', 'www', 'testing', 'staging', 'beta', 'live', 'sandbox', 'jenkins']

# EMAILS
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
DEFAULT_FROM_EMAIL = os.environ['DEFAULT_FROM_EMAIL']
SERVER_EMAIL = os.environ['SERVER_EMAIL']
EMAIL_HOST = os.environ['EMAIL_HOST']
EMAIL_PORT = int(os.environ['EMAIL_PORT'])
EMAIL_HOST_USER = os.environ['EMAIL_HOST_USER']
EMAIL_HOST_PASSWORD = os.environ['EMAIL_HOST_PASSWORD']
EMAIL_USE_TLS = os.environ['EMAIL_USE_TLS'] == 'True'
EMAIL_USE_SSL = os.environ['EMAIL_USE_SSL'] == 'True'

# CSRF
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
CSRF_TRUSTED_ORIGINS = json.loads(os.environ.get('CSRF_TRUSTED_ORIGINS', '[]'))

from localcosmos_server.settings import *

if DEBUG == True:
    SESSION_COOKIE_SECURE = False
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"


# override LOGIN_REDIRECT_URL from localcosmos_server.settings
LOGIN_REDIRECT_URL = '/'

TAGGIT_CASE_INSENSITIVE = True
TAGGIT_STRIP_UNICODE_WHEN_SLUGIFYING = True

LOCALCOSMOS_PRIVATE = False

# the location where published apps are being installed if you use auto-update
# your apps index.html will be in LOCALCOSMOS_APPS_ROOT/{APP_SUBDOMAIN}/www/index.html
# make sure to serve LOCALCOSMOS_APPS_ROOT/{APP_SUBDOMAIN}/www/ via nginx or apache
# APP_SUBSOMAIN is the subdomain of the app on localcosmos.org
LOCALCOSMOS_WWW_ROOT = '/var/www/localcosmos/'
LOCALCOSMOS_APPS_ROOT = '/var/www/localcosmos/apps/'

# DeepL integration
DEEPL_API_URL = os.environ['DEEPL_API_URL']
DEEPL_AUTH_KEY = os.environ['DEEPL_AUTH_KEY']

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'null': {
            'level': 'DEBUG',
            'class': 'logging.NullHandler',
        }
    },
    'loggers': {
        # Silence SuspiciousOperation.DisallowedHost exception ('Invalid
        # HTTP_HOST' header messages). Set the handler to 'null' so we don't
        # get those annoying emails.
        'django.security.DisallowedHost': {
            'handlers': ['null'],
            'propagate': False,
        }
    }
}