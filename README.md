### otelgen
A tool to test OTel collector capacity.

### Description

I needed a tool to send synthetic traces to the collector in my k8s cluster. This code has an image which includes parallelism so the collector can be smashed with random trace/span data. This is a fork. The original code can be found [here](https://github.com/krzko/otelgen).

I only focused on traces but it can also generate metrics. 

#### Docker

Adding parallelism 

```
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

```
Build and push the image
```
wget https://github.com/krzko/otelgen/releases/download/v0.4.1/otelgen_linux_amd64.tar.gz
mv otelgen_linux_amd64/otelgen .
podman build -t moonorb/otelgen:v1 .
podman tag localhost/moonorb/otelgen:v1 moonorb/otelgen:v1
podman push moonorb/otelgen:v1
```

#### Deployment
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "otelgen-app"
  labels:
    app: otelgen
spec:
  selector:
    matchLabels:
      app: otelgen
  replicas: 1
  template:
    metadata:
      labels:
        app: otelgen
    spec:
      containers:
      - name: otelgen
        image: moonorb/otelgen:v1
        imagePullPolicy: Always
        ports:
        - containerPort: 80
```

```
 k create ns otelgen
 k create -f otelgen-deployment.yaml -n otelgen
```

Exec to the container to send trace: 
```
k exec -it <podname> bash -n otelgen
```

Fire away(this example runs 2 otelgen processes for 10 minutes with rate of 50 traces per second). Remember to replace the collector service address

##### http
```
otelgen-app-55fc564f88-jtll4:/# parallel --line-buffer  --jobs 2 "otelgen -i -p http --otel-exporter-otlp-endpoint moonorb-collector-collector.observability.svc.cluster.local:4318 --duration 600 --rate 50 traces multi" ::: 1 2
```

##### grpc
```
otelgen-app-55fc564f88-jtll4:/# parallel --line-buffer --jobs 2 "otelgen -i -p grpc--otel-exporter-otlp-endpoint moonorb-collector-collector.observability.svc.cluster.local:4317 --duration 600 --rate 50 traces multi" ::: 1 2
```

Observe collector logs(with DEBUG): 
```
2023-05-12T23:24:35.113Z        info    TracesExporter  {"kind": "exporter", "data_type": "traces", "name": "logging", "#spans": 20}
2023-05-12T23:24:35.114Z        info    ResourceSpans #0
Resource SchemaURL: 
Resource attributes:
     -> service.name: Str(otelgen)
ScopeSpans #0
ScopeSpans SchemaURL: 
InstrumentationScope  
Span #0
    Trace ID       : d287dfe5ba081e92c95554dc042fbb8c
    Parent ID      : 0e15a10a065351b9
    ID             : b3ab73dd5fa29558
    Name           : pong
    Kind           : Internal
    Start time     : 2023-05-12 23:24:23.691927469 +0000 UTC
    End time       : 2023-05-12 23:24:24.925930694 +0000 UTC
    Status code    : Unset
    Status message : 
Attributes:
     -> span.kind: Str(server)
     -> service.namespace: Str(Demo)
     -> net.peer.name: Str(1.2.3.4)
     -> peer.service: Str(otelgen-client)
     -> service.instance.id: Str(otelgen-app-55fc564f88-jtll4)
     -> service.version: Str(1.2.3)
     -> telemetry.sdk.language: Str(go)
```