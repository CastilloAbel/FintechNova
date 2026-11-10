FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /build
COPY api-facturas/pom.xml .
RUN mvn -B -DskipTests dependency:go-offline
COPY api-facturas/src ./src
RUN mvn -B -DskipTests package

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN apt-get update \
    && apt-get install -y --only-upgrade apt libapt-pkg6.0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN useradd --system --uid 10001 --create-home appuser
COPY --from=build --chown=appuser:appuser /build/target/api-facturas.jar /app/app.jar
USER appuser

EXPOSE 8083
ENV PORT=8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]