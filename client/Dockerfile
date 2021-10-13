FROM --platform=linux/amd64 node:16-alpine AS build

WORKDIR /jasb

ARG MODE=production
ENV WEBPACK_MODE $MODE

COPY ["./package.json", "./package-lock.json", "./"]
RUN ["npm", "ci"]

COPY ["./tsconfig.json", "./postcss.config.js", "./webpack.config.js", "./elm.json", "./"]
COPY ["./src", "./src"]
COPY ["./elm-material", "./elm-material"]
COPY ["./assets", "./assets"]
RUN ["npm", "run", "build"]

FROM nginx:mainline-alpine

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=$VCS_REF-dev

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.url="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.source="https://github.com/jads-dev/jasb"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.revision=$VCS_REF
LABEL org.opencontainers.image.vendor="JADS Dev"
LABEL org.opencontainers.image.licenses="AGPL-3.0+"
LABEL org.opencontainers.image.title="JASB Web Client"
LABEL org.opencontainers.image.description="Static web client for JASB."

EXPOSE 8080

COPY --from=build ["/jasb/dist", "/usr/share/nginx/html/"]
COPY ["./nginx.conf", "/etc/nginx/nginx.conf"]
