workspace {
    name "Cargo Shipping System"
    description "Architecture for cargo shipping system based on Evans' DDD book"

    !identifiers hierarchical
    !adrs decisions
    !docs documentation

    model {
        user = person "User" "A user of the cargo shipping system"
        staff = person "Staff" "Staff member of the cargo shipping company"
        
        # Group & System Context
        group "Cargo Shipping Company" {
            cargoSystem = softwareSystem "Cargo Shipping System" "Allows customers to book and track cargo shipments" {
                # Containers
                backendSystem = container "Backend System" "Provides cargo booking and tracking functionality via a REST API" "Java, Spring Boot" {
                    # Backend Components
                    bookingService = component "Booking Service" "Handles cargo booking operations" "Spring Service"
                    trackingService = component "Tracking Service" "Handles cargo tracking operations" "Spring Service"
                    routingService = component "Routing Service" "Handles cargo routing operations" "Spring Service"
                    
                    # Domain Model Components
                    bookingDomain = component "Booking Domain" "Domain model for booking bounded context" "Java"
                    trackingDomain = component "Tracking Domain" "Domain model for tracking bounded context" "Java"
                    routingDomain = component "Routing Domain" "Domain model for routing bounded context" "Java"
                    
                    # Repository Components
                    bookingRepository = component "Booking Repository" "Repository for booking aggregates" "Spring Data"
                    trackingRepository = component "Tracking Repository" "Repository for tracking aggregates" "Spring Data"
                    routingRepository = component "Routing Repository" "Repository for routing aggregates" "Spring Data"
                    
                    # API Components
                    apiGateway = component "API Gateway" "REST API gateway for mobile applications" "Spring REST"
                    
                    # Component Relationships
                    apiGateway -> bookingService "Forwards booking requests to"
                    apiGateway -> trackingService "Forwards tracking requests to"
                    apiGateway -> routingService "Forwards routing requests to"
                    
                    bookingService -> bookingDomain "Uses"
                    trackingService -> trackingDomain "Uses"
                    routingService -> routingDomain "Uses"
                    
                    bookingDomain -> bookingRepository "Persists via"
                    trackingDomain -> trackingRepository "Persists via"
                    routingDomain -> routingRepository "Persists via"
                }
                
                bookingApp = container "Booking Mobile App" "Allows customers to book cargo shipments" "React Native" {
                    bookingUI = component "Booking UI" "User interface for booking operations" "React Native"
                    bookingClient = component "Booking API Client" "Client for the booking API" "JavaScript"
                    
                    bookingUI -> bookingClient "Uses"
                    bookingClient -> backendSystem.apiGateway "Makes API calls to" "JSON/HTTPS"
                }
                
                salesApp = container "Sales Management App" "Allows staff to manage sales and customer relationships" "React Native" {
                    salesUI = component "Sales UI" "User interface for sales operations" "React Native"
                    salesClient = component "Sales API Client" "Client for the sales API" "JavaScript"
                    
                    salesUI -> salesClient "Uses"
                    salesClient -> backendSystem.apiGateway "Makes API calls to" "JSON/HTTPS"
                }
                
                database = container "Database" "Stores all cargo shipping data" "PostgreSQL" {
                    tags "Database"
                }
                
                backendSystem -> database "Reads from and writes to" "JDBC"
            }
        }
        
        # External Systems
        paymentSystem = softwareSystem "Payment System" "Handles payment processing" "External"
        shippingPartners = softwareSystem "Shipping Partners" "External shipping providers" "External"
        
        # System Context Relationships
        user -> cargoSystem "Books and tracks cargo using"
        staff -> cargoSystem "Manages sales and customers using"
        cargoSystem -> paymentSystem "Makes payment requests to"
        cargoSystem -> shippingPartners "Coordinates shipping with"
        
        # Deployment Nodes for Production
        deploymentEnvironment "Production" {
            deploymentNode "Cloud Platform" {
                containerInstance cargoSystem.backendSystem
                containerInstance cargoSystem.database
            }
            
            deploymentNode "Mobile App Stores" {
                deploymentNode "Apple App Store" {
                    containerInstance cargoSystem.bookingApp
                    containerInstance cargoSystem.salesApp
                }
                
                deploymentNode "Google Play Store" {
                    containerInstance cargoSystem.bookingApp
                    containerInstance cargoSystem.salesApp
                }
            }
        }
    }
    
    views {
        systemContext cargoSystem "SystemContext" {
            include *
            autoLayout
        }
        
        container cargoSystem "Containers" {
            include *
            autoLayout
        }
        
        component cargoSystem.backendSystem "BackendComponents" {
            include *
            autoLayout
        }
        
        component cargoSystem.bookingApp "BookingAppComponents" {
            include *
            autoLayout
        }
        
        component cargoSystem.salesApp "SalesAppComponents" {
            include *
            autoLayout
        }
        
        # Deployment View
        deployment cargoSystem "Production" "ProductionDeployment" {
            include *
            autoLayout
        }

        # Styling
        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #1168BD
                color #ffffff
            }
            element "Mobile App" {
                shape MobileDevicePortrait
                background #438DD5
                color #ffffff
            }
        }

        # Theme
        theme default
    }
}
