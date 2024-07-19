FROM maven:3-openjdk-17-slim AS build
COPY src /usr/src/app/src
COPY pom.xml /usr/src/app
RUN mvn -f /usr/src/app/pom.xml clean package

FROM openjdk:17-oracle
COPY --from=build /usr/src/app/target/remote-falcon-plugins-api.jar /usr/app/remote-falcon-plugins-api.jar
EXPOSE 8080

ADD 'https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar' /usr/app/opentelemetry-javaagent.jar

ENTRYPOINT exec java $JAVA_OPTS -javaagent:/usr/app/opentelemetry-javaagent.jar \
                                -Dotel.exporter.otlp.endpoint=https://otel.remotefalcon.dev \
                                -Dotel.resource.attributes=service.name=remote-falcon-plugins-api \
                                -XX:FlightRecorderOptions=stackdepth=256 \
                                -jar /usr/app/remote-falcon-plugins-api.jar