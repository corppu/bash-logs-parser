.PHONY: build test test-single test-multi test-custom clean help logs up down

help:
	@echo "Pattern Matching Script - Docker Test Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build           - Build Docker image"
	@echo "  test            - Run full test suite"
	@echo "  test-single     - Run single pattern test (ERROR)"
	@echo "  test-multi      - Run multiple pattern test (ERROR|WARNING)"
	@echo "  test-custom     - Run custom timestamp regex test"
	@echo "  up              - Start docker-compose services"
	@echo "  down            - Stop docker-compose services"
	@echo "  logs            - Show docker-compose logs"
	@echo "  clean           - Clean up results and containers"
	@echo "  shell           - Open interactive shell in container"
	@echo "  help            - Show this help message"
	@echo ""

build:
	docker build -t pattern-matcher .
	@echo "✓ Docker image built"

test: build
	chmod +x test.sh
	./test.sh

test-single: build
	docker run -it --rm \
		-v $$(pwd)/test-data:/test-data \
		-v $$(pwd)/test-results:/test-results \
		pattern-matcher \
		-p "ERROR" \
		-i "/test-data" \
		-o "/test-results/test-single"
	@echo ""
	@echo "Results saved to: test-results/test-single"

test-multi: build
	docker run -it --rm \
		-v $$(pwd)/test-data:/test-data \
		-v $$(pwd)/test-results:/test-results \
		pattern-matcher \
		-p "ERROR" \
		-p "WARNING" \
		-i "/test-data" \
		-o "/test-results/test-multi"
	@echo ""
	@echo "Results saved to: test-results/test-multi"

test-custom: build
	docker run -it --rm \
		-v $$(pwd)/test-data:/test-data \
		-v $$(pwd)/test-results:/test-results \
		pattern-matcher \
		-p "Database" \
		-i "/test-data" \
		-o "/test-results/test-custom" \
		-t "^\\[[0-9]{4}-"
	@echo ""
	@echo "Results saved to: test-results/test-custom"

up: build
	docker-compose up

down:
	docker-compose down

logs:
	docker-compose logs -f

shell: build
	docker run -it --rm \
		-v $$(pwd)/test-data:/test-data \
		-v $$(pwd)/test-results:/test-results \
		pattern-matcher \
		/bin/bash

clean:
	rm -rf test-results/
	docker-compose down
	@echo "✓ Cleaned up test results and containers"

.DEFAULT_GOAL := help
