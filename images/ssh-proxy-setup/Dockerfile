FROM golang:1 AS builder
ADD ssh-proxy-setup.go /go/src/
RUN CGO_ENABLED=0 go build -o /go/bin/ssh-proxy-setup /go/src/ssh-proxy-setup.go

FROM scratch
COPY --from=builder /go/bin/ssh-proxy-setup /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/ssh-proxy-setup"]
