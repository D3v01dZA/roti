FROM ubuntu:21.04

WORKDIR /root/

COPY target/debug/roti .
COPY docker/entrypoint.sh .

EXPOSE 8080

ENTRYPOINT ["/root/entrypoint.sh"]

