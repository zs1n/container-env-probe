FROM docker.io/library/alpine:3.20
RUN apk add --no-cache curl
COPY probe.sh /probe.sh
RUN chmod +x /probe.sh
EXPOSE 80
CMD ["/bin/sh", "/probe.sh"]
