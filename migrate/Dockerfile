ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${VCS_REF}-dev


FROM scratch AS sources

COPY --link ["./src/sql", "./sql"]


FROM --platform=${BUILDPLATFORM} redgate/flyway:9 AS base

ARG VERSION
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.url="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.source="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${VCS_REF}
LABEL org.opencontainers.image.vendor="JADS Dev"
LABEL org.opencontainers.image.title="JASB Migrate"
LABEL org.opencontainers.image.description="DB migration tool for JASB."

ENV FLYWAY_URL=jdbc:postgresql://storage:5432/jasb
ENV FLYWAY_USER=jasb
ENV FLYWAY_LOCATIONS=filesystem:/flyway/sql/migrations
ENV FLYWAY_DEFAULT_SCHEMA=jasb
ENV FLYWAY_CREATE_SCHEMAS=true

WORKDIR /flyway

COPY --link --from=sources [ "/", "./" ]
