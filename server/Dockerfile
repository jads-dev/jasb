FROM node:16-alpine AS base

WORKDIR /jasb

COPY ["./package.json", "./package-lock.json", "./"]

FROM base AS build

RUN ["npm", "ci"]

COPY ["./tsconfig.json", "./"]
COPY ["./src", "./src"]
RUN ["npm", "run", "build"]

FROM base as install

RUN ["npm", "ci", "--only=production"]

FROM node:16-alpine

ARG NODE_ENV=production
ENV NODE_ENV $NODE_ENV

WORKDIR /jasb

# We've already done all our NPM stuff, but node looks here for `type: "module"` which we need.
COPY ["./package.json", "./"]
COPY --from=install ["/jasb/node_modules", "./node_modules"]

COPY --from=build ["/jasb/src/sql/migrations", "./src/sql/migrations/"]
COPY --from=build ["/jasb/dist", "./"]

EXPOSE 8081
USER node
CMD ["node", "--es-module-specifier-resolution=node", "./index.js"]
