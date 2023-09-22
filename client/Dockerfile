ARG NODE_VERSION=20
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

COPY ["./package.json", "./package-lock.json", "./elm-tooling.json", "./"]
COPY ["./elm-material/package.json", "./elm-material/package-lock.json", "./elm-material/"]
RUN ["npm", "ci"]

COPY ["./tsconfig.json", "./postcss.config.cjs", "./vite.config.mts", "./elm.json", "./"]
COPY ["./index.html", "./"]
COPY ["./src", "./src"]
COPY ["./components", "./components"]
COPY ["./elm-material/src", "./elm-material/src"]
COPY ["./assets", "./assets"]
RUN ["npm", "run", "build"]

FROM --platform=${TARGETPLATFORM} nginx:mainline-alpine

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

EXPOSE 8080

COPY --from=build ["/jasb/dist", "/usr/share/nginx/html/"]
COPY ["./nginx.conf", "/etc/nginx/nginx.conf"]
