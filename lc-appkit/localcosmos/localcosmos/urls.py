"""
URL configuration for localcosmos project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.conf import settings
from django.contrib import admin
from django.urls import path, include

from app_kit.multi_tenancy import views as multi_tenancy_views


urlpatterns = [
    path('', multi_tenancy_views.ListAppKits.as_view(), name='list_app_kits'),
    path('admin/', admin.site.urls),
    path('', include('app_kit.multi_tenancy.public_schema_urls')),
]

# remove this line after development
if settings.DEBUG:
    from django.conf.urls.static import static
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static('/build_jobs/', document_root='/var/www/localcosmos/build_jobs/')