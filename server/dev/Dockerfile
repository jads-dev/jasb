ARG NODE_VERSION=20

FROM node:${NODE_VERSION}

EXPOSE 8081

VOLUME [ "/jasb" ]
WORKDIR "/jasb/server"

ENV JASB_CONFIG_PATH "config.json5;config.dev.json5"
ENV NODE_ENV "development"

ENTRYPOINT [ "npm" ]
CMD [ "run", "dev" ]
