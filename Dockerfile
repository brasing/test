FROM alpine:3.2 AS compiler

ENV NGINX_VERSION nginx-1.9.12

RUN apk --update add build-base perl linux-headers
RUN apk --update add pcre-dev zlib-dev build-base

WORKDIR /src
ADD ./src /src

RUN cd libressl-2.6.2 \
  && ./configure LDFLAGS='-lrt -s' --prefix=/usr \
  && make \
  && make install

RUN cd nginx-1.12.2 && \
  ./configure \
    --with-cc-opt='-g -O2' \
    --with-ld-opt='-Wl,-s' \
    --sbin-path=/usr/local/nginx/nginx \
    --conf-path=/usr/local/nginx/nginx.conf \
    --pid-path=/usr/local/nginx/nginx.pid \
    --error-log-path=/dev/stderr \
    --http-log-path=/dev/stdout \
    --with-http_ssl_module \
    --with-stream \
    --without-select_module \
    --without-poll_module \
    --without-http_proxy_module \
    --without-mail_pop3_module \
    --without-mail_smtp_module \
    --without-mail_imap_module && \
  make && \
  make install

RUN strip --strip-all /lib/ld-musl-x86_64.so.1 \
  && strip --strip-all /usr/lib/libpcre.so.1 \
  && strip --strip-all /lib/libz.so.1 \
  && strip --strip-all /usr/lib/libcrypto.so.42.0.0 \
  && strip --strip-all /usr/lib/libssl.so.44.0.1

FROM scratch

COPY --from=compiler /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=compiler /usr/lib/libpcre.so.1 /usr/lib/libpcre.so.1
COPY --from=compiler /usr/lib/libssl.so.44 /usr/lib/libssl.so.44
COPY --from=compiler /usr/lib/libcrypto.so.42 /usr/lib/libcrypto.so.42
COPY --from=compiler /lib/libz.so.1 /lib/libz.so.1
COPY --from=compiler /usr/local/nginx/nginx /usr/local/nginx/nginx
COPY --from=compiler /usr/local/nginx/nginx.conf /usr/local/nginx/nginx.conf
COPY --from=compiler /usr/local/nginx/mime.types /usr/local/nginx/mime.types 
COPY --from=compiler /etc/passwd /etc/passwd
COPY --from=compiler /etc/group /etc/group

EXPOSE 80 443

CMD ["/usr/local/nginx/nginx", "-g", "daemon off;"]