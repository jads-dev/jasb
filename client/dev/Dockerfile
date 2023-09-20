ARG NODE_VERSION=20

FROM node:${NODE_VERSION}

EXPOSE 8080

VOLUME [ "/jasb" ]
WORKDIR "/jasb/client"

ENV JASB_DEV_ENV "docker"
ENV JASB_URL "http://localhost:8080/"

ENTRYPOINT [ "npm" ]
CMD [ "run", "dev" ]
