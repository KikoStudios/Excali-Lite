FROM node:18 AS builder

# Default build arguments
ARG TARGETPLATFORM
ARG CHANNEL
ARG VERSION=main
ARG GIT_REMOTE_PROJECT=https://github.com/excalidraw/excalidraw.git

WORKDIR /tmp/node_app

# Set environment variables for the build
ENV NODE_ENV=development
ENV VITE_APP_PORTAL_URL=""
ENV VITE_APP_DISABLE_TRACKING=true
ENV VITE_APP_WS_SERVER_URL=http://localhost:3002

# Clone the repository, apply a configuration change, and install dependencies
RUN git clone -b "${VERSION}" "${GIT_REMOTE_PROJECT}" . && \
    sed -i 's|"excalidraw.production.min": "./entry.js",|"excalidraw.production.min": "../../excalidraw-app/index.ts",|g' ./src/packages/excalidraw/webpack.prod.config.js && \
    yarn --ignore-optional --network-timeout 600000

# Build the application using the custom Docker build script
RUN yarn build:app:docker

# Stage 2: Use an unprivileged Nginx container to serve the built files
FROM ghcr.io/nginxinc/nginx-unprivileged:1.25-alpine

# Set the default collaboration server address
ENV COLLAB_ADDR=http://localhost:3002

WORKDIR /usr/share/nginx/html

USER root

# Copy the build output from the first stage into the Nginx container
COPY --from=builder /tmp/node_app/build /usr/share/nginx/html

# Ensure the files are owned by the nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html

USER nginx

ENTRYPOINT [ "/bin/ash" ]

# Replace the default collaboration URL in the built assets and launch Nginx
CMD [ "-c", "sed -i s,http://localhost:3002,$COLLAB_ADDR,g /usr/share/nginx/html/assets/*.js && /docker-entrypoint.sh nginx -g 'daemon off;'" ]

LABEL org.opencontainers.image.source="https://github.com/excalidraw/excalidraw"
