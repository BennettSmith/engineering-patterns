I would like to use structurizr lite in my project. I want to keep my workspace dsl file in a folder called example, 
and would like a Makefile with target rules for launching and using structurizr lite. Can you walk me step by step 
through setting this up?  I am running on a Mac laptop. 

## Structurizr DSL Rules

Make sure to follow these important rules when generating structurizr dsl files.

  * According to the structurizr dsl documentation the `enterprise` keyword has been deprecated. The `group` keyword should be used instead. 
  * When using hierarchical identifiers the dsl must include the `!identifiers hierarchical` directive.

