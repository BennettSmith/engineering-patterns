# Cargo Shipping System Overview

## Introduction

The Cargo Shipping System is designed following Domain-Driven Design (DDD) principles as described in Eric Evans' book. The system enables customers to book and track cargo shipments while providing staff with tools to manage sales and customer relationships.

## Architecture Principles

The architecture follows the principles of Clean Architecture as defined by Robert C. Martin ("Uncle Bob"):

1. **Independence from frameworks**: The system core doesn't depend on the existence of libraries or frameworks.
2. **Testability**: Business rules can be tested without UI, database, web server, or any external element.
3. **Independence from UI**: The UI can change without changing the business rules.
4. **Independence from database**: Business rules aren't bound to a specific database.
5. **Independence from external agencies**: Business rules don't know anything about interfaces to the outside world.

## Bounded Contexts

The system is divided into the following bounded contexts:

1. **Booking Context**: Handles cargo booking operations
2. **Tracking Context**: Handles cargo tracking operations
3. **Routing Context**: Handles cargo routing operations
4. **Sales Context**: Handles sales and customer relationship management

## Mobile Applications

The system includes two mobile applications:

1. **Booking App**: Customer-facing application for booking and tracking cargo
2. **Sales Management App**: Staff-facing application for managing sales and customer relationships

Both applications are developed natively:
- Android: Built with Kotlin and Jetpack Compose
- iOS: Built with Swift and SwiftUI

These native implementations follow Clean Architecture principles and provide optimal performance, full access to platform capabilities, and robust offline-first functionality.

## Backend System

The backend system provides a REST API for the mobile applications and handles all business logic. It's built using Spring Boot and follows DDD and Clean Architecture principles.
