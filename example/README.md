# Cargo Shipping System Architecture

This folder contains architecture documentation for the Cargo Shipping System, based on principles from Domain-Driven Design (Eric Evans) and Clean Architecture (Robert C. Martin).

## Prerequisites

- Docker installed on your machine
- Make utility (typically pre-installed on Mac)

## Getting Started

### Starting Structurizr Lite

To start the Structurizr Lite server:

```bash
make start
```

This will start a Docker container with Structurizr Lite and exposte the service on http://localhost:8080.

### Opening the Structurizr UI

```bash
make open
```

This will open the Structurizr UI in your default browser (Mac only).

### Checking Status

To check if Structurizr Lite is running:

```bash
make status
```

### Stopping Structurizr Lite

```bash
make stop
```

### Cleaning Up

```bash
make clean
```

## Architecture Overview

This project defines the architecture for:

1. **Cargo System Backend**
   - RESTful API defined in OpenAPI
   - Domain-driven design following Evans' principles
   - Clean Architecture principles following Uncle Bob's guidelines

2. **Mobile Applications**
   - Booking Application (iOS & Android)
   - Sales Management System (iOS & Android)

## Modifying the Architecture

Edit the `workspace.dsl` file to update the architecture documentation. The changes will be picked up automatically by the Structurizr Lite server.

## Resources

- [Structurizr DSL Documentation](https://github.com/structurizr/dsl)
- [Domain-Driven Design (Eric Evans)](https://domainlanguage.com/ddd/)
- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
