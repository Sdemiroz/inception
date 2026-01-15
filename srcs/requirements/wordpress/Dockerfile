FROM debian:bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    php8.2-fpm php8.2-cli php8.2-mysql \
    default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

RUN sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf \
 && mkdir -p /run/php /var/www/html

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
