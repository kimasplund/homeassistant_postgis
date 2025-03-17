# Contributing to PostgreSQL 17 with PostGIS Add-on

Thank you for considering contributing to this Home Assistant add-on!

## Repository Structure

This repository follows the [Home Assistant Add-on Repository](https://developers.home-assistant.io/docs/add-ons/repository) structure:

```
repository/
├── README.md
├── CONTRIBUTING.md
├── LICENSE
├── repository.yaml
└── postgresql_postgis/         # Add-on directory
    ├── config.yaml             # Add-on configuration
    ├── Dockerfile              # Add-on build instructions
    ├── build.yaml              # Add-on build configuration
    └── rootfs/                 # Add-on file system
```

## Development Guidelines

1. **Use the proper directory structure**: All add-on specific files should go in the `postgresql_postgis/` directory.
2. **Keep repository files in the root**: Files like README.md, LICENSE, and repository.yaml should remain in the root.
3. **Test thoroughly**: Test your changes locally before submitting a pull request.
4. **Follow Home Assistant standards**: Follow the [Home Assistant Add-on Development](https://developers.home-assistant.io/docs/add-ons/tutorial) guidelines.

## Submitting Changes

1. Fork the repository
2. Create a branch for your changes
3. Make your changes
4. Test your changes
5. Submit a pull request

## Questions?

If you have any questions or need help, please create an issue in the repository or contact the maintainer. 