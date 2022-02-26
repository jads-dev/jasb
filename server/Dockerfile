ARG NODE_VERSION=17
ARG MODE=production
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${VCS_REF}-dev

FROM --platform=${BUILDPLATFORM} node:${NODE_VERSION}-alpine AS base

WORKDIR /jasb

COPY ["./package.json", "./package-lock.json", "./"]

FROM base AS build

RUN ["npm", "ci"]

COPY ["./tsconfig.json", "./"]
COPY ["./src", "./src"]
RUN ["npm", "run", "build"]

FROM base as install

RUN ["npm", "ci", "--only=production"]

FROM --platform=${TARGETPLATFORM} node:${NODE_VERSION}-alpine

ARG VERSION
ARG BUILD_DATE
ARG VCS_REF
ARG MODE

ENV JASB_CONFIG_PATH "config.json5"
ENV JASB_VERSION ${VERSION}
ENV NODE_ENV ${MODE}

LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.url="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.source="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${VCS_REF}
LABEL org.opencontainers.image.vendor="JADS Dev"
LABEL org.opencontainers.image.licenses="AGPL-3.0+"
LABEL org.opencontainers.image.title="JASB Server"
LABEL org.opencontainers.image.description="Server for JASB."

WORKDIR /jasb

# We've already done all our NPM stuff, but node looks here for `type: "module"` which we need.
COPY ["./package.json", "./"]
COPY --from=install ["/jasb/node_modules", "./node_modules"]

COPY --from=build ["/jasb/src/sql/migrations", "./src/sql/migrations/"]
COPY --from=build ["/jasb/dist", "./"]

EXPOSE 8081
USER node
CMD ["node", "./index.js"]
