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

EXPOSE 8080

COPY --from=build ["/jasb/dist", "/usr/share/nginx/html/"]
COPY ["./nginx.conf", "/etc/nginx/nginx.conf"]
