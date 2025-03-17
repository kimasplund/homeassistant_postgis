# Home Assistant Add-on: PostgreSQL 17 with PostGIS

[![GitHub Release][releases-shield]][releases]
![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

PostgreSQL 17 database server with PostGIS 3.5.2 extension for Home Assistant.

## About

This add-on provides a PostgreSQL 17 database server with PostGIS 3.5.2 spatial extension, allowing you to use geospatial data with Home Assistant. The add-on supports all Home Assistant architectures including ARM-based systems like Raspberry Pi.

## Installation

Follow these steps to get the add-on installed on your system:

1. Navigate in your Home Assistant frontend to **Supervisor** -> **Add-on Store**.
2. Add this repository URL: `https://github.com/kimasplund/homeassistant_postgis`
3. Find the "PostgreSQL 17 with PostGIS" add-on and click it.
4. Click on the "INSTALL" button.

## Configuration

Example add-on configuration:

```yaml
databases:
  - homeassistant
  - geospatial_data
logins:
  - username: homeassistant
    password: password
  - username: admin
    password: secure_password
rights:
  - database: homeassistant
    username: homeassistant
    privileges: ALL
  - database: geospatial_data
    username: admin
    privileges: ALL
ssl: true
backup_time: "01:30"
max_connections: 50
shared_buffers: "128MB"
work_mem: "4MB"
maintenance_work_mem: "64MB"
effective_cache_size: "512MB"
server_args: "-c log_min_duration_statement=200"
allow_from:
  - 192.168.0.0/24
  - 10.0.0.0/8
prometheus_exporter: true
```

### Option: `databases` (required)

Database names to create when the add-on starts.

### Option: `logins` (required)

This section defines the PostgreSQL users that will be created. Each login requires:
- `username`: Username for the PostgreSQL user
- `password`: Password for the PostgreSQL user

### Option: `rights` (required)

This section defines the rights for users on databases. Each right requires:
- `database`: Database name
- `username`: Username
- `privileges`: PostgreSQL privileges (e.g., ALL, SELECT, etc.)

### Option: `ssl` (optional)

Enable or disable SSL encryption for PostgreSQL connections. Default is `false`.

### Option: `backup_time` (optional)

Time to perform daily automatic backups in 24-hour format (HH:MM). Default is `01:30`.

### Option: `max_connections` (optional)

Maximum number of concurrent connections. Default is 50, adjust based on your system's resources.

### Option: `shared_buffers` (optional)

PostgreSQL shared memory buffer size. Default is `128MB`. For Raspberry Pi 4 or better, you can increase this.

### Option: `work_mem` (optional)

Memory used for query operations. Default is `4MB`.

### Option: `maintenance_work_mem` (optional)

Memory used for maintenance operations. Default is `64MB`.

### Option: `effective_cache_size` (optional)

Estimate of how much memory is available for disk caching. Default is `512MB`.

### Option: `server_args` (optional)

Additional arguments to pass to the PostgreSQL server.

### Option: `allow_from` (optional)

List of IP networks that are allowed to connect to PostgreSQL. If empty, allows connections from anywhere.

### Option: `prometheus_exporter` (optional)

Enable or disable the Prometheus metrics exporter for PostgreSQL. Default is `false`.

## Using with Home Assistant

To use this database with Home Assistant, update your `configuration.yaml`:

```yaml
recorder:
  db_url: postgresql://homeassistant:password@a0d7b954-postgresql:5432/homeassistant
```

Replace `a0d7b954` with the short hostname of your add-on instance (visible on the add-on info page) and update the username and password accordingly.

## Backup and Restore

The add-on includes automatic daily backups at the specified time. Backups are stored in the `/backup` directory.

### Manual Backup

To manually create a backup, in the Home Assistant UI:
1. Go to Supervisor > PostgreSQL with PostGIS > Terminal
2. Run: `/usr/local/bin/backup-postgres`

### Restore from Backup

To restore from a backup, in the Home Assistant UI:
1. First, list available backups: `/usr/local/bin/restore-postgres`
2. Restore from a specific backup: `/usr/local/bin/restore-postgres postgres_backup_YYYY-MM-DD_HH-MM-SS.sql.gz`

## Prometheus Metrics

When `prometheus_exporter` is enabled, PostgreSQL metrics are exposed on port 9187. You can access them at:
`http://a0d7b954-postgresql:9187/metrics`

To view and analyze the metrics, you'll need to set up a Prometheus server and configure it to scrape metrics from this endpoint.

> **Note:** The Prometheus exporter is fully supported on amd64 and aarch64 (ARM64) architectures. For other architectures (armv7, armhf, i386), the exporter will be disabled even if enabled in configuration due to binary availability limitations.

## Using PostGIS with Home Assistant

PostGIS extends PostgreSQL with geospatial capabilities. Here are some example queries you can use with Home Assistant data:

### Example 1: Create a geometry column for device trackers

```sql
-- Add a geometry column to store locations
ALTER TABLE states 
ADD COLUMN geom geometry(POINT, 4326);

-- Update geometry data from latitude and longitude
UPDATE states 
SET geom = ST_SetSRID(ST_MakePoint(
  (attributes->>'longitude')::float, 
  (attributes->>'latitude')::float
), 4326)
WHERE domain = 'device_tracker' 
AND (attributes->>'longitude') IS NOT NULL 
AND (attributes->>'latitude') IS NOT NULL;
```

### Example 2: Find devices within a specific radius

```sql
-- Find all device trackers within 1 kilometer of a point
SELECT entity_id, attributes->>'friendly_name' as name,
  ST_Distance(
    geom, 
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography
  ) as distance_meters
FROM states
WHERE domain = 'device_tracker'
AND geom IS NOT NULL
AND ST_DWithin(
  geom::geography,
  ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography,
  1000  -- 1 kilometer radius
)
ORDER BY distance_meters;
```

### Example 3: Create geofences and check if devices are inside

```sql
-- Create a table for geofences
CREATE TABLE geofences (
  id SERIAL PRIMARY KEY,
  name TEXT,
  geom geometry(POLYGON, 4326)
);

-- Insert a sample geofence (home area)
INSERT INTO geofences (name, geom)
VALUES ('Home', ST_GeomFromText('POLYGON((-122.42 37.77, -122.41 37.77, -122.41 37.78, -122.42 37.78, -122.42 37.77))', 4326));

-- Check which devices are inside the geofence
SELECT s.entity_id, s.attributes->>'friendly_name' as name, g.name as geofence
FROM states s
JOIN geofences g ON ST_Contains(g.geom, s.geom)
WHERE s.domain = 'device_tracker'
AND s.geom IS NOT NULL;
```

## Upgrading

When upgrading the add-on, your PostgreSQL data will be preserved as it's stored in a persistent volume. However, it's recommended to:

1. Back up your databases before upgrading
2. Check the add-on release notes for any specific upgrade instructions
3. After upgrading, verify that all your databases and users are working correctly

## Performance Tuning

The default settings are conservative and suitable for most Home Assistant installations. For better performance:

- Increase `shared_buffers` to 25% of your system's RAM
- Set `work_mem` higher for complex queries (8-16MB)
- Adjust `maintenance_work_mem` to speed up maintenance operations
- Set `effective_cache_size` to 50-75% of your system's RAM

## Support

Got questions?

You have several options to get them answered:
- The [Home Assistant Discord Chat Server][discord].
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

In case you've found a bug, please [open an issue on GitHub][issue].

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[discord]: https://discord.gg/c5DvZ4e
[forum]: https://community.home-assistant.io
[issue]: https://github.com/kimasplund/homeassistant_postgis/issues
[license-shield]: https://img.shields.io/github/license/kimasplund/homeassistant_postgis.svg
[project-stage-shield]: https://img.shields.io/badge/project%20stage-experimental-yellow.svg
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/release/kimasplund/homeassistant_postgis.svg
[releases]: https://github.com/kimasplund/homeassistant_postgis/releases 