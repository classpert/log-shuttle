FROM golang:1.13-alpine AS build

ARG GO_LINKER_SYMBOL
ARG GO_LINKER_VALUE
ARG GOOS
ARG GOARCH

WORKDIR /build
ADD . /build
RUN apk update && apk add --virtual build-dependencies build-base git
RUN go mod download
RUN GOOS=${GOOS} GOARC=${GOARCH} go build -v -ldflags "-X ${GO_LINKER_SYMBOL}=${GO_LINKER_VALUE}" -o /build/log-shuttle ./cmd/log-shuttle

FROM alpine:3.10

RUN apk update && apk add ca-certificates curl jq && rm -rf /var/cache/apk/*

COPY --from=build /build/log-shuttle /bin/log-shuttle
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
