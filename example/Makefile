.PHONY: start stop status clean help

# Configuration
STRUCTURIZR_PORT=8080
STRUCTURIZR_CONTAINER_NAME=structurizr-lite
WORKSPACE_DIR=$(PWD)

# Docker command
DOCKER=docker

help:
	@echo "Structurizr Lite Makefile"
	@echo "-------------------------"
	@echo "make start    - Start Structurizr Lite server"
	@echo "make stop     - Stop Structurizr Lite server"
	@echo "make status   - Check if Structurizr Lite server is running"
	@echo "make clean    - Remove Structurizr Lite container"
	@echo "make help     - Show this help message"

start:
	@echo "Starting Structurizr Lite server..."
	@$(DOCKER) run -d --name $(STRUCTURIZR_CONTAINER_NAME) \
		-p $(STRUCTURIZR_PORT):8080 \
		-v $(WORKSPACE_DIR):/usr/local/structurizr \
		--rm \
		structurizr/lite:latest
	@echo "Structurizr Lite is running at http://localhost:$(STRUCTURIZR_PORT)"
	@echo "Your workspace is located at $(WORKSPACE_DIR)/workspace.dsl"

stop:
	@echo "Stopping Structurizr Lite server..."
	@$(DOCKER) stop $(STRUCTURIZR_CONTAINER_NAME) || echo "Structurizr Lite is not running"

status:
	@if $(DOCKER) ps | grep -q $(STRUCTURIZR_CONTAINER_NAME); then \
		echo "Structurizr Lite is running at http://localhost:$(STRUCTURIZR_PORT)"; \
	else \
		echo "Structurizr Lite is not running"; \
	fi

clean: stop
	@echo "Removing Structurizr Lite container..."
	@$(DOCKER) rm -f $(STRUCTURIZR_CONTAINER_NAME) 2>/dev/null || echo "Container already removed"
