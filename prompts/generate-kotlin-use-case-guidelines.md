# Generating Kotlin Use Case Guidelines

You are an experienced software engineer with deep knowledge of Clean Architecture. Together you and I are going to establish a set of guiding principles for how use cases are specified and developed in Kotlin for use in Android applications. I have included a domain model in the file `cargo-tracking-model.md`. If we include examples in our guidelines they should be based on the model described there. 

Some initial considerations:
* The interface for a use case should be referred to as the use case.
* The implementation of a use case should be referred to as the interactor.
* Use cases should be asynchronous, but should not raise exceptions.
* The concepts of controllers and presenters is important. Our examples should illustrate how this separation is maintained when executing use cases.
* In view models make use of the coordinator pattern to group pairs of use case controller and presenter together. 
* The core model (entities, value objects, aggregates) should follow DDD principles.
* It is okay to allow value objects to cross the use case boundary. 
* It is prohibited for entities or aggregates to cross the use case boundary.
* Use cases interactors work with repositories to access domain entities.
* Use case requests should use factory methods to validate and construct the requests.
* Validation errors should be kept separate from domain errors.

Instructions:
* The document should begin with a general explanation of how we implement and structure our code around use cases.  
* Follow up with some small code snippets in the document to illustrate the main points.
* Create an interface called `UseCase` that defines how all use cases will be structured. It should include a single execute method that takes as input a request structure and returns a response structure or domain error. The execute method should be asynchronous.
* Show how repositories can be defined and injected into a use case interactor.
* Include a discussion of how the view model, controller and presenter in the presentation layer would collaborate together when executing a use case.
* Demonstrate the technique of combining the controller and presenter in a coordinator that can then be used by the view model.
* Be sure to account for lifecycle concerns when dealing with Activities in an Android application.
* Produce a markdown document called `kotlin-use-case-guidelines.md` with the recommended approach.
