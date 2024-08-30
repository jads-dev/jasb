ARG NODE_VERSION=22
ARG MODE=production
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${VCS_REF}-dev


FROM --platform=${BUILDPLATFORM} node:${NODE_VERSION}-alpine AS build

WORKDIR /jasb

RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=package-lock.json,target=package-lock.json \
  --mount=type=cache,target=/root/.npm \
  ["npm", "ci"]

RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=package-lock.json,target=package-lock.json \
  --mount=type=bind,source=tsconfig.json,target=tsconfig.json \
  --mount=type=bind,source=src,target=src \
  ["npm", "run", "build"]


FROM build AS dev

ENV JASB_CONFIG_PATH "config.json5;config.dev.json5"
ENV JASB_VERSION "dev"
ENV NODE_ENV "development"

COPY --link [ "./", "./" ]

HEALTHCHECK CMD curl -f http://localhost:8081/api/health || exit 1
EXPOSE 8081
ENTRYPOINT ["npm"]
CMD ["run", "dev"]


FROM node:${NODE_VERSION}-alpine AS install

WORKDIR /jasb

RUN \
  --mount=type=bind,source=package.json,target=package.json \
  --mount=type=bind,source=package-lock.json,target=package-lock.json \
  --mount=type=cache,target=/root/.npm \
  ["npm", "ci", "--omit=dev"]


FROM scratch AS sources

COPY --link --from=install ["/jasb/node_modules", "./node_modules"]
COPY --link --from=build ["/jasb/dist", "./"]
# We've already done all our NPM stuff, but node looks here for `type: "module"` which we need.
COPY --link <<EOF package.json
{ "type": "module" }
EOF

FROM node:${NODE_VERSION}-alpine AS server

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

RUN \
  --mount=type=cache,target=/var/cache/apk \
  apk update; \
  apk add \
  tini \
  vips;
COPY --link --from=sources [ "/", "./" ]

HEALTHCHECK CMD curl -f http://localhost:8081/api/health || exit 1
USER node
EXPOSE 8081
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "--enable-source-maps", "./index.js"]
