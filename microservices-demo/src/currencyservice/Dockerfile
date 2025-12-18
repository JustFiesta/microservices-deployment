FROM --platform=$BUILDPLATFORM node:14.21.3@sha256:a158d3b9b4e3fa813fa6c8c590b8f0a860e015ad4e59bbce5744d2f6fd8461aa AS build

ARG TARGETOS=linux
ARG TARGETARCH=x64

WORKDIR /app
COPY package*.json ./

RUN npm install --only=production

COPY server.js ./
COPY proto ./proto

FROM gcr.io/distroless/nodejs14-debian11 AS runtime

WORKDIR /app
COPY --chown=1000:1000 --from=build /app/node_modules ./node_modules
COPY --chown=1000:1000 --from=build /app/server.js ./server.js
COPY --chown=1000:1000 --from=build /app/proto ./proto

EXPOSE 7000
USER 1000:1000

CMD ["server.js"]