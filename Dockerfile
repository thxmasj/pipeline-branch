FROM alpine:3.5

RUN apk --no-cache add git openssh bash
COPY branch.sh /usr/local/bin
WORKDIR /work

ENTRYPOINT ["branch.sh"]

