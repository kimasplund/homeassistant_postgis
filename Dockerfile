ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bullseye
FROM ${BUILD_FROM}

# Set environment variables
ENV LANG C.UTF-8
ENV PGDATA /var/lib/postgresql/data
ENV POSTGRES_PASSWORD postgres

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    wget \
    git \
    build-essential \
    make \
    rsync \
    jq \
    openssl \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL repository
RUN curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update

# Set PostgreSQL version and display architecture for debugging
ARG BUILD_ARCH=amd64
ENV PG_MAJOR 17
RUN dpkg --print-architecture > /tmp/architecture && \
    cat /tmp/architecture && \
    echo "Building for architecture: ${BUILD_ARCH}"

# Install PostgreSQL
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-${PG_MAJOR} \
    postgresql-server-dev-${PG_MAJOR} \
    postgresql-contrib-${PG_MAJOR} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PostGIS dependencies 
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgdal-dev \
    libproj-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libgeos-dev \
    libspatialindex-dev \
    libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set PostGIS version and Prometheus exporter version
ENV POSTGIS_VERSION 3.5.2
ENV PG_EXPORTER_VERSION 0.15.0

# Ensure PostgreSQL is not running
RUN service postgresql stop || true

# Download and build PostGIS
WORKDIR /usr/src
RUN wget https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz \
    && tar -xzf postgis-${POSTGIS_VERSION}.tar.gz \
    && cd postgis-${POSTGIS_VERSION} \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf postgis-${POSTGIS_VERSION}*

# Install Prometheus PostgreSQL exporter for supported architectures
RUN if [ "$BUILD_ARCH" = "amd64" ]; then \
    wget -O /tmp/postgres_exporter.tar.gz https://github.com/prometheus/postgres_exporter/releases/download/v${PG_EXPORTER_VERSION}/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz && \
    mkdir -p /usr/local/bin/postgres_exporter && \
    tar -xzf /tmp/postgres_exporter.tar.gz -C /usr/local/bin/postgres_exporter --strip-components=1 && \
    rm /tmp/postgres_exporter.tar.gz; \
    elif [ "$BUILD_ARCH" = "aarch64" ]; then \
    wget -O /tmp/postgres_exporter.tar.gz https://github.com/prometheus/postgres_exporter/releases/download/v${PG_EXPORTER_VERSION}/postgres_exporter-${PG_EXPORTER_VERSION}.linux-arm64.tar.gz && \
    mkdir -p /usr/local/bin/postgres_exporter && \
    tar -xzf /tmp/postgres_exporter.tar.gz -C /usr/local/bin/postgres_exporter --strip-components=1 && \
    rm /tmp/postgres_exporter.tar.gz; \
    else \
    mkdir -p /usr/local/bin/postgres_exporter && \
    echo "#!/bin/sh" > /usr/local/bin/postgres_exporter/postgres_exporter && \
    echo "echo 'Prometheus exporter not available for this architecture'" >> /usr/local/bin/postgres_exporter/postgres_exporter && \
    chmod +x /usr/local/bin/postgres_exporter/postgres_exporter; \
    fi

# Create backup directory
RUN mkdir -p /backup \
    && chown -R postgres:postgres /backup

# Copy root filesystem
COPY rootfs /

# Create directories and set executable permissions for scripts
RUN mkdir -p /etc/services.d/postgresql \
    /etc/services.d/prometheus-postgres-exporter \
    /etc/services.d/backup-scheduler \
    /usr/local/bin \
    && if [ -f /etc/services.d/postgresql/run ]; then chmod +x /etc/services.d/postgresql/run; fi \
    && if [ -f /etc/services.d/postgresql/finish ]; then chmod +x /etc/services.d/postgresql/finish; fi \
    && if [ -f /etc/services.d/prometheus-postgres-exporter/run ]; then chmod +x /etc/services.d/prometheus-postgres-exporter/run; fi \
    && if [ -f /etc/services.d/prometheus-postgres-exporter/finish ]; then chmod +x /etc/services.d/prometheus-postgres-exporter/finish; fi \
    && if [ -f /etc/services.d/backup-scheduler/run ]; then chmod +x /etc/services.d/backup-scheduler/run; fi \
    && if [ -f /etc/services.d/backup-scheduler/finish ]; then chmod +x /etc/services.d/backup-scheduler/finish; fi \
    && if [ -f /usr/local/bin/backup-postgres ]; then chmod +x /usr/local/bin/backup-postgres; fi \
    && if [ -f /usr/local/bin/restore-postgres ]; then chmod +x /usr/local/bin/restore-postgres; fi \
    && if [ -f /usr/local/bin/generate-ssl-cert ]; then chmod +x /usr/local/bin/generate-ssl-cert; fi

# Make sure data directory exists and has proper ownership
RUN mkdir -p ${PGDATA} && chown -R postgres:postgres ${PGDATA}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD pg_isready -U postgres || exit 1

# Set S6 Overlay entry point
ENTRYPOINT ["/init"]

# Labels
LABEL \
    io.hass.name="PostgreSQL 17 with PostGIS 3.5.2" \
    io.hass.description="PostgreSQL 17 database server with PostGIS 3.5.2 extension" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    maintainer="Kim Asplund <kim.asplund@gmail.com>" 