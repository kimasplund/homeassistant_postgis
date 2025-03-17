ARG BUILD_FROM
FROM ${BUILD_FROM}

# Set environment variables
ENV LANG C.UTF-8
ENV PGDATA /var/lib/postgresql/data
ENV POSTGRES_PASSWORD postgres

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    libreadline-dev \
    zlib1g-dev \
    libxml2-dev \
    libssl-dev \
    libxslt-dev \
    libgdal-dev \
    libproj-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    libgeos-dev \
    libspatialindex-dev \
    libpq-dev \
    postgresql-server-dev-all \
    gcc \
    g++ \
    make \
    wget \
    git \
    rsync \
    jq \
    openssl \
    tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set PostgreSQL version
ENV PG_MAJOR 17
ENV PG_VERSION 17.0

# Set PostGIS version
ENV POSTGIS_VERSION 3.5.2

# Set Prometheus exporter version
ENV PG_EXPORTER_VERSION 0.15.0

# Download and build PostgreSQL
WORKDIR /usr/src
RUN wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz \
    && tar -xzf postgresql-${PG_VERSION}.tar.gz \
    && cd postgresql-${PG_VERSION} \
    && ./configure \
        --prefix=/usr/local \
        --with-openssl \
        --with-libxml \
        --with-libxslt \
    && make -j$(nproc) \
    && make install \
    && cd contrib \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf /usr/src/postgresql-${PG_VERSION}*

# Create postgres user and group
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# Download and build PostGIS
RUN wget https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz \
    && tar -xzf postgis-${POSTGIS_VERSION}.tar.gz \
    && cd postgis-${POSTGIS_VERSION} \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf postgis-${POSTGIS_VERSION}*

# Install Prometheus PostgreSQL exporter
RUN wget -O /tmp/postgres_exporter.tar.gz https://github.com/prometheus/postgres_exporter/releases/download/v${PG_EXPORTER_VERSION}/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz \
    && mkdir -p /usr/local/bin/postgres_exporter \
    && tar -xzf /tmp/postgres_exporter.tar.gz -C /usr/local/bin/postgres_exporter --strip-components=1 \
    && rm /tmp/postgres_exporter.tar.gz

# Create PostgreSQL data directory
RUN mkdir -p /var/lib/postgresql/data \
    && chown -R postgres:postgres /var/lib/postgresql \
    && chmod 700 /var/lib/postgresql/data

# Create backup directory
RUN mkdir -p /backup \
    && chown -R postgres:postgres /backup

# Copy root filesystem
COPY rootfs /

# Set executable permissions for scripts
RUN chmod +x /etc/services.d/postgresql/run \
    && chmod +x /etc/services.d/postgresql/finish \
    && chmod +x /usr/local/bin/backup-postgres \
    && chmod +x /usr/local/bin/restore-postgres \
    && chmod +x /usr/local/bin/generate-ssl-cert

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD pg_isready -U postgres || exit 1

# Set S6 Overlay entry point
ENTRYPOINT ["/init"]

# Labels
LABEL \
    io.hass.name="PostgreSQL 17 with PostGIS" \
    io.hass.description="PostgreSQL 17 database server with PostGIS extension" \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="addon" \
    io.hass.arch="${BUILD_ARCH}" \
    maintainer="Kim Asplund <kim.asplund@gmail.com>" 