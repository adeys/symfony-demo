# Composer dependencies
FROM php:8.1-fpm-alpine as composer-dependencies
COPY --from=composer:2.2 /usr/bin/composer /usr/local/bin/composer
USER root
WORKDIR /app
COPY src/Kernel.php /app/src/Kernel.php
COPY composer.json /app/
COPY composer.lock /app/
COPY symfony.lock /app/
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Nodejs dependencies
FROM node:16-alpine as frontend-build
USER root
WORKDIR /app
COPY package.json /app/package.json
COPY yarn.lock /app/yarn.lock
COPY webpack.config.js /app/webpack.config.js
COPY assets/ /app/assets
RUN yarn
RUN yarn build

# Install php
FROM php:8.1-fpm-alpine
WORKDIR /usr/src/app
RUN apk update

# Install php dependencies
RUN apk add git icu-dev zlib-dev libzip-dev libpq-dev
RUN docker-php-ext-install zip intl pgsql pdo_pgsql

# Install nodeJS, nginx and supervisor
RUN apk add bash 'nginx=~1.20' 'supervisor=~4.2'

COPY --from=composer-dependencies /app/vendor /usr/src/app/vendor
COPY --from=frontend-build /app/public/build /usr/src/app/public/build

COPY . /usr/src/app
RUN mkdir --mode=777 var/

COPY docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/nginx/nginx.conf /etc/nginx/http.d/default.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
