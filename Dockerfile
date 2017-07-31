FROM fluent/fluentd:latest
MAINTAINER Oluwaseun Obajobi <oba@obajobi.com>

USER root

RUN apk add --no-cache --virtual .build-deps build-base ruby-dev sudo && \
    fluent-gem install --no-ri --no-rdoc fluent-plugin-gelf-hs && \
    fluent-gem install --no-ri --no-rdoc fluent-plugin-kubernetes_metadata_filter && \
    rm -rf /home/fluent/.gem/ruby/2.3.0/cache/*.gem && \
    gem sources -c && \
    apk del .build-deps && rm -rf /var/cache/apk/*

COPY ./run.sh /run.sh
RUN chmod a+x /run.sh

WORKDIR /home/fluent

ENTRYPOINT [ "/run.sh"]
