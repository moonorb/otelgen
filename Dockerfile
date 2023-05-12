FROM alpine:latest

# Install necessary dependencies and a shell
RUN apk --no-cache add ca-certificates bash

# Install 'parallel' package
RUN apk --no-cache add parallel

# Copy the Go binary into the container
COPY otelgen /usr/local/bin/otelgen

# Set the entrypoint to an infinite loop
ENTRYPOINT ["sh", "-c", "trap 'exit 0' SIGTERM; while :; do sleep 1; done"]

# Set the default command to run otelgen with specified arguments
CMD ["/usr/local/bin/otelgen", "--workers", "${WORKERS:-1}"]
