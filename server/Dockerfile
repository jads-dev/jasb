ARG NODE_VERSION=20
ARG MODE=production
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${VCS_REF}-dev


FROM --platform=${BUILDPLATFORM} node:${NODE_VERSION}-alpine AS base

WORKDIR /jasb

COPY --link ["./package.json", "./package-lock.json", "./"]


FROM base AS build

RUN ["npm", "ci"]

COPY --link ["./tsconfig.json", "./"]
COPY --link ["./src", "./src"]
RUN ["npm", "run", "build"]

# We've already done all our NPM stuff, but node looks here for `type: "module"` which we need.
RUN echo '{ "type": "module" }' > ./dist/package.json


FROM base as install

RUN ["npm", "ci", "--omit=dev", "--omit=optional"]


FROM scratch AS sources

COPY --link --from=install ["/jasb/node_modules", "./node_modules"]
COPY --link --from=build ["/jasb/dist", "./"]


FROM --platform=${TARGETPLATFORM} node:${NODE_VERSION}-alpine AS server

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

COPY --link --from=sources [ "/", "./" ]

EXPOSE 8081
CMD ["node", " --enable-source-maps", "./index.js"]
