FROM alpine:3.24 AS hugo-builder
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community hugo

FROM alpine:3.24 AS rclone-builder
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community rclone

FROM docker.n8n.io/n8nio/n8n
COPY --from=hugo-builder /usr/bin/hugo /usr/local/bin/hugo
COPY --from=hugo-builder /usr/lib/libstdc++.so.6* /usr/lib/
COPY --from=hugo-builder /usr/lib/libgcc_s.so.1* /usr/lib/
RUN hugo version

COPY --from=rclone-builder /usr/bin/rclone /usr/local/bin/rclone
RUN rclone version