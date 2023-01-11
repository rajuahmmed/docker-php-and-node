#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM php:7.4-fpm-alpine

# persistent dependencies
RUN set -eux; \
	apk add --no-cache \
# in theory, docker-entrypoint.sh is POSIX-compliant, but priority is a working, consistent image
		bash \
# Ghostscript is required for rendering PDF previews
		ghostscript \
# Alpine package for "imagemagick" contains ~120 .so files, see: https://github.com/docker-library/wordpress/pull/497
		imagemagick \
	;

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		freetype-dev \
		icu-dev \
		imagemagick-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg \
		--with-webp \
	; \
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		exif \
		gd \
		intl \
		mysqli \
		zip \
	; \
# Install Xdebug
	pecl install xdebug-3.1.6; \
	docker-php-ext-enable xdebug; \
# WARNING: imagick is likely not supported on Alpine: https://github.com/Imagick/imagick/issues/328
# https://pecl.php.net/package/imagick
	pecl install imagick-3.6.0; \
	docker-php-ext-enable imagick; \
	rm -r /tmp/pear; \
	\
# some misbehaving extensions end up outputting to stdout 🙈 (https://github.com/docker-library/wordpress/issues/669#issuecomment-993945967)
	out="$(php -r 'exit(0);')"; \
	[ -z "$out" ]; \
	err="$(php -r 'exit(0);' 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]; \
	\
	extDir="$(php -r 'echo ini_get("extension_dir");')"; \
	[ -d "$extDir" ]; \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive "$extDir" \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .wordpress-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps; \
	\
	! { ldd "$extDir"/*.so | grep 'not found'; }; \
# check for output like "PHP Warning:  PHP Startup: Unable to load dynamic library 'foo' (tried: ...)
	err="$(php --version 3>&1 1>&2 2>&3)"; \
	[ -z "$err" ]

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# https://wordpress.org/support/article/editing-wp-config-php/#configure-error-logging
RUN { \
# https://www.php.net/manual/en/errorfunc.constants.php
# https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > /usr/local/etc/php/conf.d/error-logging.ini

# SETUP PHP-FPM CONFIG SETTINGS (max_children / max_requests)
RUN echo 'pm.max_children = 15' >> /usr/local/etc/php-fpm.d/zz-docker.conf && \
    echo 'pm.max_requests = 500' >> /usr/local/etc/php-fpm.d/zz-docker.conf

# Change xdebug mode to develop
RUN echo 'xdebug.mode=develop,debug' >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install SVN
RUN apk add --no-cache subversion

# Install node, yarn and npm
ENV NODE_VERSION 14.21.2

RUN addgroup -g 1000 node \
		&& adduser -u 1000 -G node -s /bin/sh -D node \
		&& apk add --no-cache \
				libstdc++ \
		&& apk add --no-cache --virtual .build-deps \
				curl \
		&& ARCH= && alpineArch="$(apk --print-arch)" \
			&& case "${alpineArch##*-}" in \
				x86_64) \
					ARCH='x64' \
					CHECKSUM="069d9b0f9c01fa269dfe71e0b65f04a151c233c81bd998b59894c5f717f79877" \
					;; \
				*) ;; \
			esac \
	&& if [ -n "${CHECKSUM}" ]; then \
		set -eu; \
		curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
		echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
			&& tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
			&& ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
	else \
		echo "Building from source" \
		# backup build
		&& apk add --no-cache --virtual .build-deps-full \
				binutils-gold \
				g++ \
				gcc \
				gnupg \
				libgcc \
				linux-headers \
				make \
				python3 \
		# gpg keys listed at https://github.com/nodejs/node#release-keys
		&& for key in \
			4ED778F539E3634C779C87C6D7062848A1AB005C \
			141F07595B7B3FFE74309A937405533BE57C7D57 \
			74F12602B6F1C4E913FAA37AD3A89613643B6201 \
			61FC681DFB92A079F1685E77973F295594EC4689 \
			8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
			C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
			890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
			C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
			108F52B48DB57BB0CC439B2997B01419BD92F80A \
		; do \
			gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
			gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
		done \
		&& curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
		&& curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
		&& gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
		&& grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
		&& tar -xf "node-v$NODE_VERSION.tar.xz" \
		&& cd "node-v$NODE_VERSION" \
		&& ./configure \
		&& make -j$(getconf _NPROCESSORS_ONLN) V= \
		&& make install \
		&& apk del .build-deps-full \
		&& cd .. \
		&& rm -Rf "node-v$NODE_VERSION" \
		&& rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
	fi \
	&& rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
	&& apk del .build-deps \
	# smoke tests
	&& node --version \
	&& npm --version

ENV YARN_VERSION 1.22.19

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
	&& for key in \
		6A010C5166006599AA17F08146C2130DFD2497F5 \
	; do \
		gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
	done \
	&& curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
	&& curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
	&& gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
	&& mkdir -p /opt \
	&& tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
	&& ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
	&& ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
	&& rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
	&& apk del .build-deps-yarn \
	# smoke test
	&& yarn --version

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
