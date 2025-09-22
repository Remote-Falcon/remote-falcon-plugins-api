FROM container-registry.oracle.com/graalvm/native-image:21 AS build
WORKDIR /app
COPY . .

RUN sed -i 's/\r$//' ./gradlew && chmod +x ./gradlew

# --- Datadog Java tracer (latest) ---
RUN mkdir -p /opt/dd
RUN curl -fsSL -o /opt/dd/dd-java-agent.jar https://dtdg.co/latest-java-tracer

ARG MONGO_URI
ARG OTEL_URI
ENV MONGO_URI=${MONGO_URI}
ENV OTEL_URI=${OTEL_URI}

# Build the **native** image and inject the agent at build time
# NOTE: quarkus.native.additional-build-args takes a comma-separated list; every item that
# starts with -J is forwarded to the JVM that runs native-image.
RUN ./gradlew clean build \
    -Dquarkus.package.jar.enabled=false \
    -Dquarkus.native.enabled=true \
    -Dquarkus.native.container-build=false \
    -Dquarkus.native.builder-image=graalvm \
    -Dquarkus.native.container-runtime=docker \
    -Dquarkus.native.additional-build-args="-J-javaagent:/opt/dd/dd-java-agent.jar" \
    -Dquarkus.mongodb.connection-string=${MONGO_URI} \
    -Dquarkus.otel.enabled=false \
    -Dquarkus.otel.exporter.otlp.endpoint=${OTEL_URI}

FROM registry.access.redhat.com/ubi9/ubi-minimal:9.2
WORKDIR /app
RUN chown 1001 /app && chmod "g+rwX" /app && chown 1001:root /app
COPY --from=build --chown=1001:root /app/build/*-runner /app/application

ARG MONGO_URI
ARG OTEL_URI
ENV MONGO_URI=${MONGO_URI}
ENV OTEL_URI=${OTEL_URI}

ENV DD_SERVICE=remote-falcon-plugins-api
ENV DD_ENV=prod

EXPOSE 8080
USER 1001

ENTRYPOINT [ \
  "/app/application", \
  "-Dquarkus.http.host=0.0.0.0", \
  "-Dquarkus.mongodb.connection-string=${MONGO_URI}", \
  "-Dquarkus.otel.exporter.otlp.endpoint=${OTEL_URI}", \
  "-Dquarkus.otel.enabled=false" \
]

