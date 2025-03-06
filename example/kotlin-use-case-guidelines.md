# Kotlin Use Case Guidelines for Android Applications

## Introduction

This document outlines our guiding principles for implementing use cases in Kotlin for Android applications following Clean Architecture and Domain-Driven Design principles. These guidelines are designed to ensure a clear separation of concerns, maintainable code structure, and adherence to best practices.

In our architecture, use cases (sometimes referred to as interactors) represent the application-specific business rules and orchestrate the flow of data between the presentation layer and the domain layer. They encapsulate a single, well-defined operation that the application can perform.

## Core Principles

1. **Use cases as interfaces**: The interface defining the operation is referred to as the "use case", while its implementation is the "interactor".
2. **Asynchronous execution**: All use cases operate asynchronously but do not raise exceptions.
3. **Clear boundaries**: Value objects may cross the use case boundary, but entities and aggregates must not.
4. **Separation of concerns**: Controllers transform UI input into use case requests, and presenters transform use case responses into UI models.
5. **Coordinator pattern**: In view models, we group controller-presenter pairs using the coordinator pattern.
6. **Repository interaction**: Use case interactors work with repositories to access domain entities.
7. **Input validation**: Use case requests should use factory methods for validation and construction.
8. **Error separation**: We distinguish between validation errors and domain errors.

## The UseCase Interface

All use cases in the system will implement a common `UseCase` interface:

```kotlin
/**
 * Base interface for all use cases in the application.
 * @param RequestT The type of the request parameter
 * @param ResponseT The type of the successful response
 * @param ErrorT The type of domain error that can occur
 */
interface UseCase<RequestT, ResponseT, ErrorT> {
    /**
     * Executes the use case asynchronously.
     * @param request The input parameters
     * @return Either a success response or a domain error
     */
    suspend fun execute(request: RequestT): Result<ResponseT, ErrorT>
}
```

The `Result` type is a sealed class representing either success or failure:

```kotlin
sealed class Result<out T, out E> {
    data class Success<out T>(val value: T) : Result<T, Nothing>()
    data class Failure<out E>(val error: E) : Result<Nothing, E>()
}
```

## Request and Response Objects

Request and response objects are immutable data structures that define the inputs and outputs of a use case. 

### Example: Booking Cargo Use Case

```kotlin
// Request with factory method for validation
data class BookCargoRequest private constructor(
    val customerId: String,
    val origin: LocationCode,
    val destination: LocationCode,
    val arrivalDeadline: LocalDateTime,
    val cargoDetails: CargoDetails
) {
    companion object {
        fun create(
            customerId: String,
            origin: String,
            destination: String,
            arrivalDeadlineString: String,
            cargoDetails: CargoDetails
        ): Result<BookCargoRequest, ValidationError> {
            // Parse date time string
            val arrivalDeadline = try {
                LocalDateTime.parse(arrivalDeadlineString, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            } catch (e: Exception) {
                return Result.Failure(ValidationError.InvalidDateFormat)
            }
            
            // Input validation
            when {
                customerId.isBlank() -> 
                    return Result.Failure(ValidationError.InvalidCustomerId)
                origin == destination -> 
                    return Result.Failure(ValidationError.SameOriginAndDestination)
                arrivalDeadline.isBefore(LocalDateTime.now()) -> 
                    return Result.Failure(ValidationError.PastArrivalDeadline)
                // Additional validations...
            }

            return try {
                Result.Success(
                    BookCargoRequest(
                        customerId,
                        LocationCode(origin),
                        LocationCode(destination),
                        arrivalDeadline,
                        cargoDetails
                    )
                )
            } catch (e: IllegalArgumentException) {
                Result.Failure(ValidationError.InvalidLocationCode)
            }
        }
    }
}

// Response
data class BookCargoResponse(
    val trackingId: String,
    val estimatedArrival: LocalDateTime,
    val itinerarySummary: List<ItinerarySummaryItem>
)

// Value object that can safely cross boundaries
data class ItinerarySummaryItem(
    val voyageNumber: String,
    val from: String,
    val to: String,
    val departureTime: LocalDateTime,
    val arrivalTime: LocalDateTime
)

// Domain errors
sealed class BookCargoError {
    object NoRouteFound : BookCargoError()
    object CustomerNotFound : BookCargoError()
    object InsufficientCapacity : BookCargoError()
    data class RepositoryError(val message: String) : BookCargoError()
}

// Validation errors
sealed class ValidationError {
    object InvalidCustomerId : ValidationError()
    object SameOriginAndDestination : ValidationError()
    object PastArrivalDeadline : ValidationError()
    object InvalidLocationCode : ValidationError()
    object InvalidDateFormat : ValidationError()
}
```

## Implementing a Use Case Interactor

The use case interactor implements the business logic, coordinates between repositories, and enforces domain rules:

```kotlin
class BookCargoInteractor(
    private val cargoRepository: CargoRepository,
    private val customerRepository: CustomerRepository,
    private val routingService: RoutingService
) : UseCase<BookCargoRequest, BookCargoResponse, BookCargoError> {

    override suspend fun execute(request: BookCargoRequest): Result<BookCargoResponse, BookCargoError> {
        // 1. Check if customer exists
        val customer = customerRepository.findById(request.customerId) 
            ?: return Result.Failure(BookCargoError.CustomerNotFound)

        // 2. Create route specification (domain value object)
        val routeSpecification = RouteSpecification(
            origin = request.origin,
            destination = request.destination,
            arrivalDeadline = request.arrivalDeadline
        )

        // 3. Find suitable routes
        val itineraries = routingService.findItineraries(routeSpecification)
        if (itineraries.isEmpty()) {
            return Result.Failure(BookCargoError.NoRouteFound)
        }

        // 4. Select best itinerary (in a real app, this might involve more complex logic)
        val selectedItinerary = itineraries.first()

        // 5. Create new Cargo entity
        val trackingId = cargoRepository.nextTrackingId()
        val cargo = Cargo.createNew(
            trackingId = trackingId,
            routeSpecification = routeSpecification,
            customer = customer,
            details = request.cargoDetails
        )

        // 6. Assign itinerary to cargo
        cargo.assignToItinerary(selectedItinerary)

        // 7. Save the cargo
        try {
            cargoRepository.save(cargo)
        } catch (e: Exception) {
            return Result.Failure(BookCargoError.RepositoryError(e.message ?: "Unknown error"))
        }

        // 8. Create and return the response
        return Result.Success(
            BookCargoResponse(
                trackingId = trackingId.value,
                estimatedArrival = selectedItinerary.finalArrivalDate,
                itinerarySummary = selectedItinerary.legs.map { leg ->
                    ItinerarySummaryItem(
                        voyageNumber = leg.voyage.voyageNumber.number,
                        from = leg.loadLocation.name,
                        to = leg.unloadLocation.name,
                        departureTime = leg.loadTime,
                        arrivalTime = leg.unloadTime
                    )
                }
            )
        )
    }
}
```

## Repository Interfaces

Repositories provide an abstraction over data sources and are crucial for the use case interactors to access domain entities:

```kotlin
interface CargoRepository {
    suspend fun findByTrackingId(trackingId: TrackingId): Cargo?
    suspend fun save(cargo: Cargo)
    suspend fun nextTrackingId(): TrackingId
    suspend fun findAll(): List<Cargo>
}

interface CustomerRepository {
    suspend fun findById(id: String): Customer?
    suspend fun findAll(): List<Customer>
    suspend fun save(customer: Customer)
}
```

## The Presentation Layer: Controllers, Presenters, and Coordinators

### Controller

The controller transforms UI input into use case requests:

```kotlin
class BookCargoController(private val bookCargoUseCase: UseCase<BookCargoRequest, BookCargoResponse, BookCargoError>) {
    
    suspend fun bookCargo(
        customerId: String,
        origin: String,
        destination: String,
        arrivalDeadlineString: String,
        cargoDetails: CargoDetails
    ): ControllerResult {
        // Create and validate the request - date parsing now happens inside the factory method
        val requestResult = BookCargoRequest.create(
            customerId, origin, destination, arrivalDeadlineString, cargoDetails
        )
        
        // Handle validation errors
        if (requestResult is Result.Failure) {
            return ControllerResult.ValidationError(requestResult.error)
        }
        
        // Execute use case
        val request = (requestResult as Result.Success).value
        val useCaseResult = bookCargoUseCase.execute(request)
        
        return when (useCaseResult) {
            is Result.Success -> ControllerResult.Success(useCaseResult.value)
            is Result.Failure -> ControllerResult.DomainError(useCaseResult.error)
        }
    }
    
    sealed class ControllerResult {
        data class Success(val response: BookCargoResponse) : ControllerResult()
        data class ValidationError(val error: ValidationError) : ControllerResult()
        data class DomainError(val error: BookCargoError) : ControllerResult()
    }
}
```

### Presenter

The presenter transforms use case responses into UI models:

```kotlin
class BookCargoPresenter {
    
    fun presentSuccess(response: BookCargoResponse): BookCargoUiState.Success {
        return BookCargoUiState.Success(
            trackingId = response.trackingId,
            estimatedArrival = formatDateTime(response.estimatedArrival),
            itinerarySummary = response.itinerarySummary.map { item ->
                ItinerarySummaryUiModel(
                    voyageNumber = item.voyageNumber,
                    fromLocation = item.from,
                    toLocation = item.to,
                    departureTime = formatDateTime(item.departureTime),
                    arrivalTime = formatDateTime(item.arrivalTime)
                )
            }
        )
    }
    
    fun presentValidationError(error: ValidationError): BookCargoUiState.Error {
        val errorMessage = when (error) {
            is ValidationError.InvalidCustomerId -> "Invalid customer ID"
            is ValidationError.SameOriginAndDestination -> "Origin and destination cannot be the same"
            is ValidationError.PastArrivalDeadline -> "Arrival deadline cannot be in the past"
            is ValidationError.InvalidLocationCode -> "Invalid location code"
            is ValidationError.InvalidDateFormat -> "Invalid date format"
        }
        return BookCargoUiState.Error(errorMessage)
    }
    
    fun presentDomainError(error: BookCargoError): BookCargoUiState.Error {
        val errorMessage = when (error) {
            is BookCargoError.NoRouteFound -> "No suitable route found for your shipment"
            is BookCargoError.CustomerNotFound -> "Customer not found"
            is BookCargoError.InsufficientCapacity -> "Insufficient capacity on selected route"
            is BookCargoError.RepositoryError -> "System error: ${error.message}"
        }
        return BookCargoUiState.Error(errorMessage)
    }
    
    private fun formatDateTime(dateTime: LocalDateTime): String {
        // Format date time for UI
        return dateTime.format(DateTimeFormatter.ofPattern("MMM dd, yyyy HH:mm"))
    }
}

// UI models
sealed class BookCargoUiState {
    object Loading : BookCargoUiState()
    data class Success(
        val trackingId: String,
        val estimatedArrival: String,
        val itinerarySummary: List<ItinerarySummaryUiModel>
    ) : BookCargoUiState()
    data class Error(val message: String) : BookCargoUiState()
}

data class ItinerarySummaryUiModel(
    val voyageNumber: String,
    val fromLocation: String,
    val toLocation: String,
    val departureTime: String,
    val arrivalTime: String
)
```

### Coordinator Pattern

The coordinator pattern combines controller and presenter into a single component that can be used by the ViewModel:

```kotlin
class BookCargoCoordinator(
    private val controller: BookCargoController,
    private val presenter: BookCargoPresenter
) {
    suspend fun bookCargo(
        customerId: String,
        origin: String,
        destination: String,
        arrivalDeadlineString: String,
        cargoDetails: CargoDetails
    ): BookCargoUiState {
        // Execute controller (which will handle date parsing)
        val controllerResult = controller.bookCargo(
            customerId, origin, destination, arrivalDeadlineString, cargoDetails
        )
        
        // Call the appropriate presenter method based on the result type
        return when (controllerResult) {
            is BookCargoController.ControllerResult.Success -> 
                presenter.presentSuccess(controllerResult.response)
            is BookCargoController.ControllerResult.ValidationError -> 
                presenter.presentValidationError(controllerResult.error)
            is BookCargoController.ControllerResult.DomainError -> 
                presenter.presentDomainError(controllerResult.error)
        }
    }
}
```

## ViewModel Implementation with Lifecycle Awareness

The ViewModel uses the coordinator to execute use cases and manage the UI state:

```kotlin
class BookCargoViewModel(
    private val coordinator: BookCargoCoordinator
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<BookCargoUiState>(BookCargoUiState.Loading)
    val uiState: StateFlow<BookCargoUiState> = _uiState.asStateFlow()
    
    fun bookCargo(
        customerId: String,
        origin: String,
        destination: String,
        arrivalDeadlineString: String,
        cargoDetails: CargoDetails
    ) {
        viewModelScope.launch {
            try {
                _uiState.value = BookCargoUiState.Loading
                
                // Execute the use case via coordinator
                // The date parsing will be handled inside the controller's validation
                val result = coordinator.bookCargo(
                    customerId, origin, destination, arrivalDeadlineString, cargoDetails
                )
                
                _uiState.value = result
            } catch (e: Exception) {
                _uiState.value = BookCargoUiState.Error("An unexpected error occurred: ${e.message}")
            }
        }
    }
}
```

## Activity Implementation with Lifecycle Awareness

The Activity observes the ViewModel's state and handles lifecycle concerns:

```kotlin
class BookCargoActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityBookCargoBinding
    private lateinit var viewModel: BookCargoViewModel
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        binding = ActivityBookCargoBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        // Initialize ViewModel with dependency injection (e.g., using Hilt)
        viewModel = ViewModelProvider(this)[BookCargoViewModel::class.java]
        
        setupListeners()
        observeUiState()
    }
    
    private fun setupListeners() {
        binding.submitButton.setOnClickListener {
            val customerId = binding.customerIdInput.text.toString()
            val origin = binding.originInput.text.toString()
            val destination = binding.destinationInput.text.toString()
            val deadline = binding.deadlineInput.text.toString()
            
            // Create cargo details from form inputs
            val cargoDetails = CargoDetails(
                // ... extract from UI
            )
            
            viewModel.bookCargo(customerId, origin, destination, deadline, cargoDetails)
        }
    }
    
    private fun observeUiState() {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    when (state) {
                        is BookCargoUiState.Loading -> showLoading()
                        is BookCargoUiState.Success -> showSuccess(state)
                        is BookCargoUiState.Error -> showError(state.message)
                    }
                }
            }
        }
    }
    
    private fun showLoading() {
        binding.progressBar.visibility = View.VISIBLE
        binding.contentGroup.visibility = View.GONE
        binding.errorText.visibility = View.GONE
    }
    
    private fun showSuccess(state: BookCargoUiState.Success) {
        binding.progressBar.visibility = View.GONE
        binding.contentGroup.visibility = View.VISIBLE
        binding.errorText.visibility = View.GONE
        
        // Update UI with success data
        binding.trackingIdText.text = "Tracking ID: ${state.trackingId}"
        binding.estimatedArrivalText.text = "Estimated Arrival: ${state.estimatedArrival}"
        
        // Update itinerary list
        val adapter = ItineraryAdapter(state.itinerarySummary)
        binding.itineraryRecyclerView.adapter = adapter
    }
    
    private fun showError(message: String) {
        binding.progressBar.visibility = View.GONE
        binding.contentGroup.visibility = View.GONE
        binding.errorText.visibility = View.VISIBLE
        binding.errorText.text = message
    }
}
```

## Summary of Key Practices

1. **Clean Separation of Concerns**:
   - Use cases (interfaces) define the application's business operations
   - Interactors (implementations) orchestrate domain logic and repositories
   - Controllers transform UI input to use case requests
   - Presenters transform use case responses to UI models
   - Coordinators combine controllers and presenters for ViewModel convenience

2. **Asynchronous Operations**:
   - All use cases operate asynchronously using Kotlin's `suspend` functions
   - Kotlin Coroutines handle background threading concerns
   - StateFlow provides reactive UI updates

3. **Error Handling**:
   - Validation errors are caught and handled early
   - Domain errors are represented as sealed classes
   - No exceptions are propagated from use cases

4. **Lifecycle Management**:
   - ViewModels handle configuration changes
   - `repeatOnLifecycle` ensures proper collection of StateFlow
   - CoroutineScope is tied to appropriate lifecycle components

5. **Domain Integrity**:
   - Entities and aggregates never cross use case boundaries
   - Value objects are allowed to cross boundaries when appropriate
   - Factory methods validate input before creating request objects

By following these guidelines, we create a clean, maintainable architecture that separates concerns appropriately, handles asynchronous operations elegantly, and maintains the integrity of our domain model.
