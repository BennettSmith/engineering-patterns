# Swift Use Case Guidelines for Clean Architecture

## Introduction

This document outlines the guidelines for implementing use cases in Swift following Clean Architecture principles for our cargo shipping system. Use cases represent the application-specific business rules and orchestrate the flow of data between the UI layer and the domain layer. They encapsulate and implement all of the use cases of the system.

In our architecture:
- **Use Case**: The interface or protocol that defines the business operation
- **Interactor**: The concrete implementation of a use case
- **Controller**: Converts UI input to a format suitable for the use case
- **Presenter**: Converts use case output to a format suitable for the UI
- **Coordinator**: Combines controller and presenter functionality for view model consumption

## Core Principles

1. Use cases should be asynchronous but should not raise exceptions
2. Value objects may cross the use case boundary, but entities and aggregates must not
3. Use case interactors work with repositories to access domain entities
4. Input validation should occur at the boundary using factory methods
5. Validation errors should be kept separate from domain errors
6. Controllers transform UI input into use case requests and return either responses or errors without transformation
7. Presenters transform responses, domain errors, and validation errors into view model states
8. Coordinators orchestrate the flow between controllers and presenters, determining the type of error and routing to the appropriate presenter method

## Use Case Protocol

All use cases in our system will conform to the following protocol:

```swift
/// Represents a use case in the system
protocol UseCase {
    associatedtype RequestType
    associatedtype ResponseType
    
    /// Executes the use case with the provided request
    /// - Parameter request: The input parameters for the use case
    /// - Returns: Either a response or a domain error
    func execute(request: RequestType) async -> Result<ResponseType, DomainError>
}
```

## Domain Errors

Domain errors represent failures that can occur during use case execution:

```swift
/// Represents errors that can occur in the domain layer
enum DomainError: Error {
    case notFound(String)
    case invalidOperation(String)
    case validationError(ValidationError)
    case unauthorized
    case repositoryError(Error)
    // Add other domain-specific errors as needed
}

/// Represents validation errors for use case input
struct ValidationError {
    let fieldErrors: [String: String]
    
    var description: String {
        return fieldErrors.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
```

## Use Case Request/Response

Requests and responses should be defined as structs that encapsulate the input and output data:

```swift
struct BookCargoRequest {
    let originLocationCode: String
    let destinationLocationCode: String
    let arrivalDeadline: Date
    let customerId: String
    
    // Factory method for validation
    static func create(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    ) -> Result<BookCargoRequest, ValidationError> {
        var fieldErrors = [String: String]()
        
        if originLocationCode.isEmpty {
            fieldErrors["originLocationCode"] = "Origin location code is required"
        }
        
        if destinationLocationCode.isEmpty {
            fieldErrors["destinationLocationCode"] = "Destination location code is required"
        }
        
        if originLocationCode == destinationLocationCode {
            fieldErrors["destinationLocationCode"] = "Destination must be different from origin"
        }
        
        if arrivalDeadline <= Date() {
            fieldErrors["arrivalDeadline"] = "Arrival deadline must be in the future"
        }
        
        if customerId.isEmpty {
            fieldErrors["customerId"] = "Customer ID is required"
        }
        
        if !fieldErrors.isEmpty {
            return .failure(ValidationError(fieldErrors: fieldErrors))
        }
        
        return .success(BookCargoRequest(
            originLocationCode: originLocationCode,
            destinationLocationCode: destinationLocationCode,
            arrivalDeadline: arrivalDeadline,
            customerId: customerId
        ))
    }
}

struct BookCargoResponse {
    let trackingId: String
    
    // Transform to value object if needed
    func toTrackingId() -> TrackingId {
        return TrackingId(id: trackingId)
    }
}
```

## Repositories

Repositories provide a way to access domain entities without exposing the underlying data source:

```swift
/// Repository interface for Cargo entities
protocol CargoRepository {
    func findByTrackingId(_ trackingId: TrackingId) async -> Result<Cargo, DomainError>
    func save(_ cargo: Cargo) async -> Result<Void, DomainError>
    func nextTrackingId() async -> Result<TrackingId, DomainError>
}

/// Repository interface for Location entities
protocol LocationRepository {
    func findByCode(_ locationCode: LocationCode) async -> Result<Location, DomainError>
    func findAll() async -> Result<[Location], DomainError>
}

/// Repository interface for Customer entities
protocol CustomerRepository {
    func findById(_ customerId: String) async -> Result<Customer, DomainError>
}
```

## Use Case Implementation

A typical use case interactor implementation:

```swift
final class BookCargoInteractor: UseCase {
    typealias RequestType = BookCargoRequest
    typealias ResponseType = BookCargoResponse
    
    private let cargoRepository: CargoRepository
    private let locationRepository: LocationRepository
    private let customerRepository: CustomerRepository
    
    init(
        cargoRepository: CargoRepository,
        locationRepository: LocationRepository,
        customerRepository: CustomerRepository
    ) {
        self.cargoRepository = cargoRepository
        self.locationRepository = locationRepository
        self.customerRepository = customerRepository
    }
    
    func execute(request: BookCargoRequest) async -> Result<BookCargoResponse, DomainError> {
        // Validate existence of locations
        let originResult = await locationRepository.findByCode(LocationCode(code: request.originLocationCode))
        
        guard case .success(let origin) = originResult else {
            if case .failure(let error) = originResult {
                return .failure(error)
            }
            return .failure(.invalidOperation("Could not find origin location"))
        }
        
        let destinationResult = await locationRepository.findByCode(LocationCode(code: request.destinationLocationCode))
        
        guard case .success(let destination) = destinationResult else {
            if case .failure(let error) = destinationResult {
                return .failure(error)
            }
            return .failure(.invalidOperation("Could not find destination location"))
        }
        
        // Check customer exists
        let customerResult = await customerRepository.findById(request.customerId)
        
        guard case .success(_) = customerResult else {
            if case .failure(let error) = customerResult {
                return .failure(error)
            }
            return .failure(.invalidOperation("Could not find customer"))
        }
        
        // Create route specification
        let routeSpecification = RouteSpecification(
            origin: origin,
            destination: destination,
            arrivalDeadline: request.arrivalDeadline
        )
        
        // Get new tracking ID
        let trackingIdResult = await cargoRepository.nextTrackingId()
        
        guard case .success(let trackingId) = trackingIdResult else {
            if case .failure(let error) = trackingIdResult {
                return .failure(error)
            }
            return .failure(.invalidOperation("Could not generate tracking ID"))
        }
        
        // Create new cargo
        let cargo = Cargo(
            trackingId: trackingId,
            origin: origin,
            routeSpecification: routeSpecification,
            itinerary: nil,
            deliverySpecification: nil,
            deliveryProgress: DeliveryProgress(
                transportStatus: .NOT_RECEIVED,
                lastKnownLocation: origin,
                currentVoyage: nil,
                isOnTrack: true,
                estimatedTimeOfArrival: request.arrivalDeadline
            )
        )
        
        // Save cargo
        let saveResult = await cargoRepository.save(cargo)
        
        guard case .success(_) = saveResult else {
            if case .failure(let error) = saveResult {
                return .failure(error)
            }
            return .failure(.invalidOperation("Failed to save cargo"))
        }
        
        // Return response with tracking ID
        return .success(BookCargoResponse(trackingId: trackingId.id))
    }
}
```

## Controller and Presenter Pattern

The controller and presenter pattern helps maintain a clear separation of concerns:

```swift
// Controller transforms UI input to use case request
protocol BookCargoController {
    func bookCargo(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    ) async -> Result<BookCargoResponse, Error>
}

// Concrete controller implementation
final class BookCargoControllerImpl: BookCargoController {
    private let useCase: any UseCase<BookCargoRequest, BookCargoResponse>
    
    init(useCase: any UseCase<BookCargoRequest, BookCargoResponse>) {
        self.useCase = useCase
    }
    
    func bookCargo(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    ) async -> Result<BookCargoResponse, Error> {
        // Create and validate request
        let requestResult = BookCargoRequest.create(
            originLocationCode: originLocationCode,
            destinationLocationCode: destinationLocationCode,
            arrivalDeadline: arrivalDeadline,
            customerId: customerId
        )
        
        // Handle validation errors
        guard case .success(let request) = requestResult else {
            if case .failure(let validationError) = requestResult {
                return .failure(validationError)
            }
            return .failure(ValidationError(fieldErrors: ["general": "Invalid request format"]))
        }
        
        // Execute use case and pass its result directly
        // This preserves the original error type (DomainError)
        return await useCase.execute(request: request)
    }
}

// Presenter transforms responses and errors to view model states
protocol BookCargoPresenter {
    func present(response: BookCargoResponse)
    func presentError(error: DomainError)
    func presentValidationError(error: ValidationError)
}

final class BookCargoPresenterImpl: BookCargoPresenter {
    private let viewModel: BookCargoViewModel
    
    init(viewModel: BookCargoViewModel) {
        self.viewModel = viewModel
    }
    
    func present(response: BookCargoResponse) {
        viewModel.updateState(.success(response.trackingId))
    }
    
    func presentError(error: DomainError) {
        switch error {
        case .validationError(let validationError):
            presentValidationError(error: validationError)
            
        case .notFound(let message):
            viewModel.updateState(.failure("Not found: \(message)"))
            
        case .invalidOperation(let message):
            viewModel.updateState(.failure(message))
            
        default:
            viewModel.updateState(.failure("An unexpected error occurred"))
        }
    }
    
    func presentValidationError(error: ValidationError) {
        viewModel.updateState(.validationFailure(error.fieldErrors))
    }
}
```

## Coordinator Pattern

The Coordinator pattern combines the controller and presenter into a single component:

```swift
// Coordinator combines controller and presenter functionality
final class BookCargoCoordinator {
    private let controller: BookCargoController
    private let presenter: BookCargoPresenter
    
    init(controller: BookCargoController, presenter: BookCargoPresenter) {
        self.controller = controller
        self.presenter = presenter
    }
    
    func bookCargo(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    ) async {
        // Call controller to execute the use case
        let result = await controller.bookCargo(
            originLocationCode: originLocationCode,
            destinationLocationCode: destinationLocationCode,
            arrivalDeadline: arrivalDeadline,
            customerId: customerId
        )
        
        // Handle result and delegate to appropriate presenter method
        switch result {
        case .success(let response):
            presenter.present(response: response)
            
        case .failure(let error):
            if let validationError = error as? ValidationError {
                // Handle validation errors from request creation
                presenter.presentValidationError(error: validationError)
            } else if let domainError = error as? DomainError {
                // Handle domain errors from use case execution
                presenter.presentError(error: domainError)
            } else {
                // Handle unexpected errors
                presenter.presentError(error: DomainError.repositoryError(error))
            }
        }
    }
}
```

## View Model Integration

The view model can use the coordinator to execute use cases:

```swift
// View model state enum
enum BookCargoViewState {
    case idle
    case loading
    case success(String)
    case validationFailure([String: String])
    case failure(String)
}

// View model protocol
protocol BookCargoViewModel: AnyObject {
    var state: BookCargoViewState { get }
    func updateState(_ newState: BookCargoViewState)
    func bookCargo(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    )
}

// View model implementation
final class BookCargoViewModelImpl: BookCargoViewModel, ObservableObject {
    @Published private(set) var state: BookCargoViewState = .idle
    
    private let coordinator: BookCargoCoordinator
    
    init(coordinator: BookCargoCoordinator) {
        self.coordinator = coordinator
    }
    
    func updateState(_ newState: BookCargoViewState) {
        DispatchQueue.main.async {
            self.state = newState
        }
    }
    
    func bookCargo(
        originLocationCode: String,
        destinationLocationCode: String,
        arrivalDeadline: Date,
        customerId: String
    ) {
        updateState(.loading)
        
        Task {
            await coordinator.bookCargo(
                originLocationCode: originLocationCode,
                destinationLocationCode: destinationLocationCode,
                arrivalDeadline: arrivalDeadline,
                customerId: customerId
            )
        }
    }
}
```

## Dependency Injection for Use Cases and Coordinators

Proper dependency injection for use cases, controllers, presenters, and coordinators:

```swift
// Factory for creating use cases
final class UseCaseFactory {
    private let cargoRepository: CargoRepository
    private let locationRepository: LocationRepository
    private let customerRepository: CustomerRepository
    
    init(
        cargoRepository: CargoRepository,
        locationRepository: LocationRepository,
        customerRepository: CustomerRepository
    ) {
        self.cargoRepository = cargoRepository
        self.locationRepository = locationRepository
        self.customerRepository = customerRepository
    }
    
    func makeBookCargoUseCase() -> any UseCase<BookCargoRequest, BookCargoResponse> {
        return BookCargoInteractor(
            cargoRepository: cargoRepository,
            locationRepository: locationRepository,
            customerRepository: customerRepository
        )
    }
    
    func makeTrackCargoUseCase() -> any UseCase<TrackCargoRequest, TrackCargoResponse> {
        return TrackCargoInteractor(
            cargoRepository: cargoRepository
        )
    }
    
    // Add other use case factory methods as needed
}

// Factory for creating coordinators
final class CoordinatorFactory {
    private let useCaseFactory: UseCaseFactory
    
    init(useCaseFactory: UseCaseFactory) {
        self.useCaseFactory = useCaseFactory
    }
    
    func makeBookCargoCoordinator(viewModel: BookCargoViewModel) -> BookCargoCoordinator {
        let useCase = useCaseFactory.makeBookCargoUseCase()
        let presenter = BookCargoPresenterImpl(viewModel: viewModel)
        let controller = BookCargoControllerImpl(useCase: useCase)
        
        return BookCargoCoordinator(
            controller: controller,
            presenter: presenter
        )
    }
    
    // Add other coordinator factory methods as needed
}
```

## Example Use Case Flow

Here's a complete example of booking a cargo:

1. The UI collects input from the user (origin, destination, deadline, etc.)
2. The UI calls the view model's `bookCargo` method
3. The view model:
   - Updates its state to loading
   - Delegates to the coordinator
4. The coordinator delegates to the controller
5. The controller:
   - Creates and validates the request (returning validation error if invalid)
   - Executes the use case if validation passes
   - Returns either the response or error (without transforming domain errors)
6. The use case interactor:
   - Retrieves necessary entities via repositories
   - Performs domain operations
   - Returns a response or domain error
7. The coordinator:
   - Examines the result from the controller
   - For success: Passes the response to the presenter's `present` method
   - For validation errors: Passes to the presenter's `presentValidationError` method
   - For domain errors: Passes to the presenter's `presentError` method
8. The presenter:
   - Formats the response or error appropriately
   - Updates the view model state
9. The UI reacts to the view model state change

## Conclusion

By following these guidelines, we ensure that our use cases:
- Maintain a clear separation of concerns
- Prevent domain logic leaking into the UI
- Keep validation and domain errors separate
- Follow asynchronous patterns without exceptions
- Protect domain boundaries
- Support testability through dependency injection

This architecture provides a maintainable and scalable foundation for our cargo shipping system's mobile applications, adhering to the principles of Clean Architecture and Domain-Driven Design.
