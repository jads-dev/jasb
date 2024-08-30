ARG NODE_VERSION=22
ARG NGINX_BASE="nginx:mainline-alpine"
ARG MODE=production
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=${VCS_REF}-dev


FROM --platform=${BUILDPLATFORM} node:${NODE_VERSION}-alpine AS build

WORKDIR /jasb

ARG VERSION
ARG MODE
ARG URL

ENV JASB_VERSION ${VERSION}
ENV JASB_BUILD_MODE ${MODE}
ENV JASB_URL ${URL}

COPY --link ["./package.json", "./package-lock.json", "./elm-tooling.json", "./"]
COPY --link ["./elm-material/package.json", "./elm-material/package-lock.json", "./elm-material/"]
RUN \
  --mount=type=cache,target=/root/.npm \
  ["npm", "ci"]

COPY --link ["./tsconfig.json", "./postcss.config.js", "./vite.config.mts", "./elm.json", "./"]
COPY --link ["./index.html", "./"]
COPY --link ["./src", "./src"]
COPY --link ["./components", "./components"]
COPY --link ["./elm-material/src", "./elm-material/src"]
COPY --link ["./assets", "./assets"]
RUN ["npm", "run", "build"]


FROM build AS dev

ENV NODE_ENV "development"
ENV JASB_DEV_ENV "docker"

COPY --link [ "./", "./" ]

HEALTHCHECK CMD curl -f http://localhost:8080/api/health || exit 1
EXPOSE 8080
ENTRYPOINT ["npm"]
CMD ["run", "dev"]


FROM scratch AS sources

COPY --link --from=build ["/jasb/dist", "/"]


FROM ${NGINX_BASE} AS client

ARG VERSION
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.url="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.source="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.version=${VERSION}
LABEL org.opencontainers.image.revision=${VCS_REF}
LABEL org.opencontainers.image.vendor="JADS Dev"
LABEL org.opencontainers.image.licenses="AGPL-3.0+"
LABEL org.opencontainers.image.title="JASB Web Client"
LABEL org.opencontainers.image.description="Static web client for JASB."

# HTTP
EXPOSE 8080
# HTTPS
EXPOSE 8083 

HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1
COPY --link --from=sources ["/", "/usr/share/nginx/html/"]
COPY --link ["./nginx/nginx.conf", "/etc/nginx/nginx.conf"]
