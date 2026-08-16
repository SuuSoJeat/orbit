FROM alpine:3.22

WORKDIR /opt/orbit

COPY bin ./bin
COPY templates ./templates
COPY README.md VERSION Makefile ./

RUN chmod 755 /opt/orbit/bin/orbit

ENTRYPOINT ["/opt/orbit/bin/orbit"]
