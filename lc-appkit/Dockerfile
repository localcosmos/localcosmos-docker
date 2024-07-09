############################################################
# Dockerfile for the official Local Cosmos App Kit image
# VERSION: 1.0
# - based on ubuntu 24.04
# - django 5.0
# - python 3.12
# - nodejs
# - nginx webserver
# - android sdk
############################################################
FROM ubuntu:24.04

LABEL maintainer = "Thomas Uher <thomas.uher@code-for-nature.com>"

ARG PYTHON_VERSION=3.12
ARG POSTGRESQL_VERSION=16
ARG OPENJDK_VERSION=11
ARG INKSCAPE_VERSION=1.2.2-2ubuntu7

ARG APP_KIT_VERSION=0.3.2

# Android Studio and Gradle will be installed after downloading the appropriate zip files
ARG GRADLE_VERSION=7.6
ARG GRADLE_FILENAME=gradle-$GRADLE_VERSION-bin.zip
ARG GRADLE_URL=https://services.gradle.org/distributions/$GRADLE_FILENAME
ARG ANDROID_COMMAND_LINE_TOOLS_FILENAME=commandlinetools-linux-6200805_latest.zip
ARG ANDROID_COMMAND_LINE_TOOLS_URL=https://dl.google.com/android/repository/$ANDROID_COMMAND_LINE_TOOLS_FILENAME

# nodejs will be installed using nvm
# https://nodejs.org/en/download/package-manager
ARG NODE_VERSION=22.3.0
ARG NVM_URL=https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/UTC

ENV PYTHONIOENCODING=utf-8
# Matplotlib created a temporary cache directory at /tmp/matplotlib-ukr0m13g because the default path (/root/.config/matplotlib) is not a writable directory; it is highly recommended to set the MPLCONFIGDIR environment variable to a writable directory, in particular to speed up the import of Matplotlib and to better support multiprocessing.
ENV MPLCONFIGDIR=/tmp/

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

# install software from ubuntu repositories
# - basic applications
# - python
# - inkscape, openjdk
# - nginx
RUN apt-get update &&\
    apt-get install --no-install-recommends -y curl nano dialog wget unzip memcached net-tools sudo gpg &&\
    apt-get install --no-install-recommends -y python$PYTHON_VERSION python3-pip python$PYTHON_VERSION-venv &&\
        apt-get install --no-install-recommends -y build-essential python$PYTHON_VERSION-dev postgresql-server-dev-$POSTGRESQL_VERSION &&\
    apt-get install --no-install-recommends -y inkscape &&\
    apt-get install --no-install-recommends -y openjdk-$OPENJDK_VERSION-jdk &&\
    apt-get install --no-install-recommends -y binutils libproj-dev gdal-bin &&\
    apt-get install --no-install-recommends -y nginx &&\
    apt-get clean autoclean &&\
    apt-get autoremove -y &&\
    rm -rf /var/lib/{apt,dpkg,cache,log}/


# install gradle from file
WORKDIR /tmp
RUN wget $GRADLE_URL &&\
	mkdir /opt/gradle &&\
	unzip $GRADLE_FILENAME -d /opt/gradle &&\
	rm $GRADLE_FILENAME

ENV PATH="/opt/gradle/gradle-$GRADLE_VERSION/bin:${PATH}"

# install android sdk
WORKDIR /tmp
RUN mkdir /opt/Android &&\
	mkdir /opt/Android/Sdk &&\
	mkdir /opt/Android/Sdk/cmdline-tools &&\
	wget $ANDROID_COMMAND_LINE_TOOLS_URL &&\
	unzip $ANDROID_COMMAND_LINE_TOOLS_FILENAME -d /opt/Android/Sdk/cmdline-tools &&\
	rm $ANDROID_COMMAND_LINE_TOOLS_FILENAME

ENV PATH="/opt/Android/Sdk/cmdline-tools/tools/bin:${PATH}"
ENV ANDROID_SDK_ROOT="/opt/Android/Sdk"
ENV ANDROID_HOME="/opt/Android/Sdk"

WORKDIR /opt/Android/Sdk
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} "build-tools;33.0.2" "platforms;android-33" "extras;android;m2repository"

# install nodejs
WORKDIR /tmp
RUN mkdir -p /usr/local/nvm
ENV NVM_DIR /usr/local/nvm
RUN curl -o- ${NVM_URL} | bash
RUN . ${NVM_DIR}/nvm.sh && nvm install ${NODE_VERSION} &&\
    nvm alias default $NODE_VERSION &&\
    nvm use default &&\
	rm -rf /var/lib/{apt,dpkg,cache,log}/

# add the node commands like npm to PATH to make it accessible for the Cordova Builder
ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin
ENV PATH $NODE_PATH:$PATH

# create the uwsgi user to not run uwsgi as root
RUN useradd uwsgi

# install django
ENV PIP_ROOT_USER_ACTION=ignore
RUN mkdir /opt/localcosmos

# set the environment variable required by localcosmos-cordova-builder
# eg node_modules will be installed in this directory
ENV LOCALCOSMOS_CORDOVA_BUILDER_WORKDIR=/opt/localcosmos-cordova-builder

ENV VIRTUAL_ENV=/opt/localcosmos/venv

RUN python$PYTHON_VERSION -m venv $VIRTUAL_ENV

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# install all django apps and requirements
RUN pip install setuptools &&\
    pip install localcosmos-app-kit==$APP_KIT_VERSION &&\
    pip install uwsgi &&\
    mkdir -p /var/log/uwsgi/

# copy the localcosmos django project
COPY ["localcosmos", "/opt/localcosmos/"]
COPY ["uwsgi", "/opt/localcosmos/uwsgi"]

RUN mkdir /opt/localcosmos/uwsgi/socket

WORKDIR /opt/localcosmos

# nginx
COPY ["nginx/localcosmos.conf", "/etc/nginx/conf.d/localcosmos.conf"]
EXPOSE 8000



CMD ["sh", "-c", "uwsgi --ini /opt/localcosmos/uwsgi/localcosmos_uwsgi.ini &&\
                  nginx -g 'daemon off;'"]

