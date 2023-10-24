Doing a test deployment:

Copy in client/nginx.conf here, and edit to:
 - Set the server names to `localhost` or whatever you are using.
 - Replace the object storage URL with a real one.
     - You can set up a Pre-Authenticated Request and use that link.
     - You can make the bucket public and use a normal link.
     - You can not set up object storage at all and just remove that section.

Copy in server/config.json5 here and edit to:
 - Set the clientOrigin to the server name.
 - Set auth.key to a suitable value.
 - Set auth.discord values.
 - Set object storage values if you want to set it up.

From the project root run `URL=https://localhost docker buildx bake --set=\*.platform=linux/amd64`,
replacing `https://localhost` value with the server name, and `linux/amd64` with your platform if 
it isn't that.

Do `docker compose run migrate`.
Do `docker compose --profile serve up`
