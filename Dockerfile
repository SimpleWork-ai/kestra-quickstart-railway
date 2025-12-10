# Simple template to deploy Kestra on Railway
ARG IMAGE_TAG=latest-lts
FROM kestra/kestra:${IMAGE_TAG}

WORKDIR /app
RUN mkdir -p /app/config /app/flows /app/storage \
  && chmod -R 777 /app/storage

# Custom entrypoint to adapt Railway's DATABASE_URL to a JDBC URL
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Main configuration file
COPY application.yaml /app/config/application.yaml
# (Uncomment if you want to ship sample flows with the image)
# COPY flows /app/flows

EXPOSE 8080 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=5 \
  CMD wget -qO- http://127.0.0.1:8081/health/readiness || exit 1

# Entry point must call the kestra binary (via our adapter script)
CMD ["/app/entrypoint.sh"]
