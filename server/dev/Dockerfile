ARG NODE_VERSION=19

FROM node:${NODE_VERSION}-alpine

EXPOSE 8081

VOLUME [ "/jasb/server" ]
WORKDIR "/jasb/server"

ENV JASB_CONFIG_PATH "config.json5;config.dev.json5"
ENV NODE_ENV "development"

ENTRYPOINT [ "npm" ]
CMD [ "run", "dev" ]
