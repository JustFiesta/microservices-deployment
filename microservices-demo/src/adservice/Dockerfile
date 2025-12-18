FROM --platform=$BUILDPLATFORM gradle:8.5-jdk21 AS build

ARG TARGETOS=linux
ARG TARGETARCH=x64
ARG TARGETRID=${TARGETOS}-${TARGETARCH}
ARG TARGETPLATFORM

WORKDIR /app
COPY . .

RUN chmod +x gradlew
RUN ./gradlew installDist --no-daemon
RUN jdeps --ignore-missing-deps -q  \
    --recursive  \  
    --multi-release 17  \
    --print-module-deps  \
    /app/build/install/hipstershop/lib/*.jar > modules.txt
RUN jlink \
    --add-modules $(cat modules.txt) \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress 2 \
    --output /min-app-jre

FROM debian:bookworm-slim@sha256:b1a741487078b369e78119849663d7f1a5341ef2768798f7b7406c4240f86aef AS runtime

WORKDIR /app

COPY --chown=1000:1000 --from=build /min-app-jre /app/jre
COPY --chown=1000:1000 --from=build /app/build/install/hipstershop /app

ENV JAVA_HOME=/app/jre
ENV PATH="${JAVA_HOME}/bin:${PATH}"

EXPOSE 9555
USER 1000:1000

ENTRYPOINT ["/app/bin/AdService"]