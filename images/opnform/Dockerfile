# OpnForm API (Laravel, php-fpm) + an nginx front in one container: nginx is the public listener, serves /api through
# php-fpm on loopback and proxies everything else to the Nuxt client service on Railway's private network. The queue
# worker and the scheduler run in the same container so all three share the one storage volume (Railway volumes
# cannot be shared between services). The upstream image and its entrypoint (migrations, Passport keys, cache
# warm-up) run unmodified.
ARG OPNFORM_API_IMAGE=jhumanj/opnform-api:2.5.0@sha256:8cf89fb82d0d3b9a2381edf4b95abf7a2bfb2f61c4cef4f14fea0b98a53016f2
FROM ${OPNFORM_API_IMAGE}

ARG WRAPPER_VERSION=0.0.0-local
ARG VCS_REF=local
LABEL org.opencontainers.image.title="opnform-railway" \
      org.opencontainers.image.description="OpnForm API + nginx front for Railway (first user created from env)" \
      org.opencontainers.image.source="https://github.com/youssefsiam38/opnform-railway" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

RUN apk add --no-cache nginx \
    && rm -f /etc/nginx/http.d/default.conf \
    && mkdir -p /etc/opnform-railway /run/nginx

COPY images/opnform/nginx.conf.template /etc/opnform-railway/nginx.conf.template
COPY images/opnform/php-fpm-loopback.conf /usr/local/etc/php-fpm.d/zzz-railway.conf
COPY images/opnform/bootstrap-admin.php /etc/opnform-railway/bootstrap-admin.php
COPY images/opnform/entrypoint.sh /usr/local/bin/opnform-railway-entrypoint
COPY images/opnform/run.sh /usr/local/bin/opnform-railway-run
RUN chmod 755 /usr/local/bin/opnform-railway-entrypoint /usr/local/bin/opnform-railway-run \
    && chmod 644 /etc/opnform-railway/*

ENV PORT=8080 \
    CLIENT_UPSTREAM=client:3000 \
    NGINX_MAX_BODY_SIZE=64m \
    APP_ENV=production \
    SELF_HOSTED=true \
    DB_CONNECTION=pgsql \
    CACHE_DRIVER=redis \
    QUEUE_CONNECTION=redis \
    SESSION_DRIVER=redis \
    LOG_CHANNEL=errorlog \
    FILESYSTEM_DRIVER=local \
    LOCAL_FILESYSTEM_VISIBILITY=public \
    MAIL_MAILER=log \
    OPNFORM_RAILWAY_VERSION=${WRAPPER_VERSION}

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/opnform-railway-entrypoint"]
