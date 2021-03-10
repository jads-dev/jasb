FROM node:15-alpine AS base

WORKDIR /party

COPY ["./package.json", "./package-lock.json", "./"]

FROM base AS build

RUN ["npm", "ci"]

COPY ["./src", "./src"]
COPY ["./tsconfig.json", "./"]
RUN ["npm", "run", "build"]

FROM base as install

RUN ["npm", "ci", "--only=production"]

FROM node:15-alpine

ARG NODE_ENV=production
ENV NODE_ENV $NODE_ENV

WORKDIR /party

# We've already done all our NPM stuff, but node looks here for `type: "module"` which we need.
COPY ["./package.json", "./"]
COPY --from=install ["/party/node_modules", "./node_modules"]

COPY --from=build ["/party/dist", "./"]

EXPOSE 8081
USER node
CMD ["node", "--es-module-specifier-resolution=node", "./index.js"]
