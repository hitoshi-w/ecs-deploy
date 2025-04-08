FROM php:8.3-fpm-bullseye AS base

WORKDIR /var/www

ENV TZ=UTC \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  LC_ALL=en_US.UTF-8 \
  COMPOSER_HOME=/composer

ARG UID=1000
ARG GID=1000

COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

RUN <<EOF
  apt-get update
  apt-get -y install --no-install-recommends \
    locales \
    git \
    unzip \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    default-mysql-client
  locale-gen en_US.UTF-8
  localedef -f UTF-8 -i en_US en_US.UTF-8
  docker-php-ext-install \
    intl \
    pdo_mysql \
    zip \
    bcmath
  groupadd --gid $GID phper
  useradd --uid $UID --gid $GID phper
  mkdir /composer
  mkdir -p /home/phper/.config/psysh
  chown phper:phper /composer
  chown phper:phper /var/www
  chown phper:phper /home/phper/.config/psysh
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF

FROM base AS development

COPY php.development.ini /usr/local/etc/php/php.ini

USER phper

FROM base AS development-xdebug

RUN <<EOF
  pecl install xdebug
  docker-php-ext-enable xdebug
EOF

COPY .xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

USER phper

FROM base AS deploy

COPY php.deploy.ini /usr/local/etc/php/php.ini
COPY --chown=phper:phper ./src /var/www

USER phper

RUN <<EOF
  composer install --quiet --no-interaction --no-ansi --no-dev --no-scripts --no-progress --prefer-dist
  composer dump-autoload --optimize
  chmod -R 777 storage bootstrap/cache
  php artisan optimize:clear
  php artisan optimize
EOF

EXPOSE 9000

FROM nginx:1.27 AS web

WORKDIR /var/www

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=deploy /var/www /var/www

EXPOSE 80