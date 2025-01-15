# Variables with default values
PG_CONTAINER ?= postgres13
PG_DEFAULT_DB ?= trace_connect
PG_USER ?= traceadmin

# Function to check required variables
check-required-var = \
	@set -e; \
	if [ -z "$($(1))" ]; then \
		echo "Error: $1 is required"; \
		exit 1; \
	fi

default: help

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done


#DB related commands

.PHONY: dump-all
dump-all: # Command to dump all databases to a file
	docker exec -t $(PG_CONTAINER) pg_dumpall -c -U $(PG_USER) > bkp/pgdump-`date +%d-%m-%Y"-"%H:%M:%S`.sql

.PHONY: restore-all
restore-all: # Command to restore all databases from a file
	$(call check-required-var,RESTORE_FILEPATH)
	cat $(RESTORE_FILEPATH) | docker exec -i $(PG_CONTAINER) psql -U $(PG_USER) -d $(PG_DEFAULT_DB)

.PHONY: dump-all-compress
dump-all-compress: # Command to dump all databases to a compressed file
	docker exec -t $(PG_CONTAINER) pg_dumpall -c -U $(PG_USER) | gzip > bkp/pgdump-`date +%d-%m-%Y"-"%H:%M:%S`.gz

.PHONY: restore-all-compress
restore-all-compress: # Command to restore all databases from a compressed file
	$(call check-required-var,RESTORE_FILEPATH)
	gunzip < $(RESTORE_FILEPATH) | docker exec -i $(PG_CONTAINER) psql -U $(PG_USER) -d $(PG_DEFAULT_DB)

.PHONY: dump-db
dump-db: # Command to dump a specific databases to a file
	$(call check-required-var,PG_DBNAME)
	docker exec -t $(PG_CONTAINER) pg_dump -U $(PG_USER) $(PG_DBNAME) > bkp/$(PG_DBNAME)-`date +%d-%m-%Y"-"%H:%M:%S`.sql

.PHONY: restore-db
restore-db: # Command to restore a specific databases
	$(call check-required-var,RESTORE_FILEPATH)
	$(call check-required-var,PG_DBNAME)
	docker exec -i $(PG_CONTAINER) psql -U $(PG_USER) -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$(PG_DBNAME)'" | grep -q 1 || docker exec -i $(PG_CONTAINER) psql -U $(PG_USER) -d postgres -c "CREATE DATABASE $(PG_DBNAME)"
	cat $(RESTORE_FILEPATH) | docker exec -i $(PG_CONTAINER) psql -U $(PG_USER) $(PG_DBNAME)


#Service commands

.PHONY: stop-all
stop-all: # Stop all running containers
	docker stop $$(docker ps -aq)

.PHONY: stop-and-remove
stop-and-remove: # Stop and remove all running containers
	docker stop $$(docker ps -aq) && docker rm $$(docker ps -aq)

.PHONY: clean-all
clean-all: # Stop all running containers, remove all containers, and clear all volumes
	docker stop $$(docker ps -aq) && docker rm $$(docker ps -aq) && docker volume rm $$(docker volume ls -q) && docker image prune


#Base commands

.PHONY: django-shell
django-shell: # Run Django shell
	docker exec -it tc-django python3 manage.py shell

.PHONY: django-shellplus
django-shellplus: # Run Django shell_plus
	docker exec -it tc-django python3 manage.py shell_plus

.PHONY: collect-static
collect-static: # Collect static files
	docker exec -it tc-django python3 manage.py collectstatic

.PHONY: reload-nginx
reload-nginx: # Reload Nginx configuration
	docker exec nginx-proxy nginx -s reload

.PHONY: django-logs
django-logs: # Tail Django logs
	docker logs -f tc-django

.PHONY: celery-logs
celery-logs: # Tail Celery logs
	docker logs -f tc-celery

.PHONY: celery-beat-logs
celery-beat-logs: # Tail Celery Beat logs
	docker logs -f tc-celery-beat

.PHONY: run-tests
run-tests: # Run tests
	docker exec -it tc-django python3 manage.py test

.PHONY: make-migrations
make-migrations: # Make database migrations
	docker exec -it tc-django python3 manage.py makemigrations

.PHONY: migrate
migrate: # Apply database migrations
	docker exec -it tc-django python3 manage.py migrate

.PHONY: flush-db
flush-db: # Flush the django database
	docker exec -it tc-django python3 manage.py flush --noinput

.PHONY: pg-shell
pg-shell: # Command to run an interactive shell in the PostgreSQL container
	docker exec -it $(PG_CONTAINER) sh


#Enviroment related commands

.PHONY: up
up: # Bring up the environment
	docker-compose -f compose/local-compose.yml up

.PHONY: up-build
up-build: # Build and bring up the environment
	docker-compose -f compose/local-compose.yml up --build

.PHONY: build-django
build-django: # Build the Django service without cache
	docker-compose -f compose/local-compose.yml build django --no-cache

.PHONY: debug-up
debug-up: # Bring up the environment with debug tools
	docker-compose -f compose/local-compose.yml -f compose/debug-compose.yml up

.PHONY: down
down: # Bring down the environment
	docker-compose -f compose/local-compose.yml down

.PHONY: debug-down
debug-down: # Bring down the environment with debug tools
	docker-compose -f compose/local-compose.yml -f compose/debug-compose.yml down

.PHONY: dev-up
dev-up: # Bring up the environment
	docker-compose -f compose/dev-compose.yml up

.PHONY: dev-down
dev-down: # Bring down the environment
	docker-compose -f compose/dev-compose.yml down

.PHONY: stage-up
stage-up: # Bring up the environment
	docker-compose -f compose/staging-compose.yml up

.PHONY: stage-down
stage-down: # Bring down the environment
	docker-compose -f compose/staging-compose.yml down

.PHONY: stage-debug-up
stage-debug-up: # Bring up the environment
	docker-compose -f compose/staging-compose.yml -f compose/debug-compose.yml up

.PHONY: stage-debug-down
stage-debug-down: # Bring down the environment
	docker-compose -f compose/staging-compose.yml -f compose/debug-compose.yml down

.PHONY: prod-up
prod-up: # Bring up the environment
	docker-compose -f compose/production-compose.yml up

.PHONY: prod-down
prod-down: # Bring down the environment
	docker-compose -f compose/production-compose.yml down

.PHONY: prod-debug-up
prod-debug-up: # Bring up the environment
	docker-compose -f compose/production-compose.yml -f compose/debug-compose.yml up

.PHONY: prod-debug-down
prod-debug-down: # Bring down the environment
	docker-compose -f compose/production-compose.yml -f compose/debug-compose.yml down

.PHONY: login
login: #docker login
	docker login

.PHONY: logout
logout: #docker logout
	docker logout