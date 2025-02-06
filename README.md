# Connect  Infra 


# Setup and Hosting Guide

## Overview
This repository contains an automated setup script and Makefile for efficiently configuring and deploying the application. The setup script ensures all dependencies are installed, configures Nginx authentication, and prepares the environment, while the Makefile provides commands for managing databases, services, and the Django project.

## Prerequisites
- A Unix-based system (Linux or macOS)
- Sudo privileges (for package installation)
- Docker and Docker Compose installed

## Features
### Setup Script
- Detects the operating system platform.
- Installs missing dependencies (`curl`, `git`, `docker`, and `apache2-utils`).
- Clones the `trace_connect` repository if not already present.
- Renames `.sample` configuration files.

### Makefile
- Database management: Dump, restore, shell access.
- Service management: Start, stop, clean Docker containers.
- Django management: Shell, logs, migrations, tests.
- Environment management: Start/stop development, staging, and production environments.

## Installation and Setup
1. **Clone the repository:**
   ```bash
   git clone git@git.cied.in:fairfood/trace-v2/backend/trace_connect.git
   cd trace_connect
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## Makefile Commands
### General Commands
- `make help` – Display available commands.
- `make default` – Show help information.

### Django Management
- `make django-shell` – Open the Django shell.
- `make django-shellplus` – Open the Django shell with additional features.
- `make collect-static` – Collect static files for deployment.
- `make reload-nginx` – Reload the Nginx configuration.
- `make django-logs` – Tail Django logs.
- `make celery-logs` – Tail Celery logs.
- `make celery-beat-logs` – Tail Celery Beat logs.
- `make run-tests` – Run Django tests.
- `make make-migrations` – Generate new migrations.
- `make migrate` – Apply database migrations.
- `make flush-db` – Flush the Django database.

### Environment Management
- `make up` – Start the environment using Docker Compose.
- `make up-build` – Build and start the environment.
- `make build-django` – Build the Django service without cache.
- `make debug-up` – Start the environment with debugging enabled.
- `make down` – Stop the environment.
- `make debug-down` – Stop the debugging environment.
- `make dev-up` – Start the development environment.
- `make dev-down` – Stop the development environment.
- `make stage-up` – Start the staging environment.
- `make stage-down` – Stop the staging environment.
- `make stage-debug-up` – Start the staging environment with debugging enabled.
- `make stage-debug-down` – Stop the staging debugging environment.
- `make prod-up` – Start the production environment.
- `make prod-down` – Stop the production environment.
- `make prod-debug-up` – Start the production environment with debugging enabled.
- `make prod-debug-down` – Stop the production debugging environment.

### Database Management
- `make dump-all` – Dump all databases.
- `make restore-all RESTORE_FILEPATH=<file>` – Restore all databases.
- `make dump-all-compress` – Dump all databases as a compressed file.
- `make restore-all-compress RESTORE_FILEPATH=<file>` – Restore all databases from a compressed file.
- `make dump-db PG_DBNAME=<database>` – Dump a specific database.
- `make restore-db PG_DBNAME=<database> RESTORE_FILEPATH=<file>` – Restore a specific database.
- `make pg-shell` – Open an interactive PostgreSQL shell inside the container.

### Service Management
- `make stop-all` – Stop all running containers.
- `make stop-and-remove` – Stop and remove all running containers.
- `make clean-all` – Stop, remove containers, clear volumes, and prune images.

### Docker Authentication
- `make login` – Log into Docker.
- `make logout` – Log out from Docker.

## Docker Compose Configurations
### Common Components
- **Networks**: `backend-network`, `public-network`.
- **Secrets**: PostgreSQL and Redis credentials.
- **Volumes**: Persistent storage for database and cache.

### Environments
#### Debug (`debug-compose.yml`)
- Includes pgAdmin for database management.
- Nginx-proxy for routing requests.

#### Development (`dev-compose.yml`)
- PostgreSQL, Redis, and Django with live reloading.
- Uses verbose logging for debugging.

#### Local (`local-compose.yml`)
- Optimized for local testing.
- Mounts additional volumes for a smooth workflow.

#### Staging (`staging-compose.yml`)
- Mirrors production for final testing.
- Uses a separate Docker image version.

#### Production (`production-compose.yml`)
- Optimized for security and performance.
- Uses Gunicorn and Nginx authentication.

## Security Measures
- Secrets are securely mounted instead of using environment variables.
- Redis and PostgreSQL require authentication.
- Strict access policies for databases.

## Detailed Explanation of the Script

### Platform Detection

```bash
PLATFORM=$(uname)
if [ "$PLATFORM" != "Linux" ] && [ "$PLATFORM" != "Darwin" ]; then
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi
```

* Uses the uname command to determine the OS type.
* If the OS is not Linux or macOS, the script exits.

### Checking and Installing Dependencies

```bash
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Installing..."
    if [ "$PLATFORM" == "Linux" ]; then
        sudo apt-get update
        sudo apt-get install -y curl
    elif [ "$PLATFORM" == "Darwin" ]; then
        echo "curl is not installed. Please install it manually."
        exit 1
    fi
fi
```

* Checks if curl is installed using command -v.

* If not found, it installs curl using apt-get (Linux) or prompts manual installation (macOS).

The same logic applies for checking and installing:

* **Git** (also installs brew on macOS if missing)

* **Docker** (installs docker.io and adds the user to the docker group on Linux)

* **Apache2-utils** (for Nginx authentication setup)

### Cloning the Repository

```bash
REPO_URL="git@git.cied.in:fairfood/trace-v2/backend/trace_connect.git"
BRANCH="docker"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Cloning the repository to $PROJECT_DIR..."
    git clone --single-branch --branch "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
else
    echo "Repository already cloned at $PROJECT_DIR."
fi
```

- Defines the repository URL and branch name.

- If the directory does not already exist, it clones the repository.

### Renaming .sample Files

```bash
echo "Renaming .sample files in the env folder..."
find "$SCRIPT_DIR/env" -type f -name "*.sample" | while read -r file; do
    dest="${file%.sample}"
    echo "Renaming: $file -> $dest"
    mv "$file" "$dest"
done
```

- Finds all .sample files in the env directory.
- Renames them by removing .sample.
- Uses find and mv to process each file.
- The same logic is applied for renaming .sample files in services/secrets.

### Setting Up Nginx Authentication

```bash
echo "Generating .htpasswd for Nginx..."
HTPASSWD_FILE="$SCRIPT_DIR/nginx/.htpasswd"
SAMPLE_HTPASSWD_FILE="$SCRIPT_DIR/nginx/.htpasswd.sample"

if [ -f "$SAMPLE_HTPASSWD_FILE" ]; then
    read -p "Enter username for Nginx: " NGINX_USER
    read -s -p "Enter password for Nginx: " NGINX_PASSWORD
    echo
    htpasswd -cb "$HTPASSWD_FILE" "$NGINX_USER" "$NGINX_PASSWORD"
    rm -f "$SAMPLE_HTPASSWD_FILE"
else
    echo ".htpasswd.sample file not found. Skipping replacement."
fi
```

- If .htpasswd.sample exists, the user is prompted for a username and password.
- The htpasswd command generates an encrypted password file.
- The sample file is then deleted.

### Final Output

```bash
echo "✔ Setup completed successfully."
```

- Displays a success message at the end of execution.