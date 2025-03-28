#!/bin/bash

# Check platform
PLATFORM=$(uname)
if [ "$PLATFORM" != "Linux" ] && [ "$PLATFORM" != "Darwin" ]; then
    echo "Unsupported platform: $PLATFORM"
    exit 1
fi

echo "Checking requirements..."

# Check if curl is installed
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

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Installing..."
    if [ "$PLATFORM" == "Linux" ]; then
        sudo apt-get update
        sudo apt-get install -y git
    elif [ "$PLATFORM" == "Darwin" ]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install git
    fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing..."
    if [ "$PLATFORM" == "Linux" ]; then
        # Install Docker on Linux
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
    elif [ "$PLATFORM" == "Darwin" ]; then
        # Install Docker on macOS
        brew install docker
        brew install docker-compose
        open /Applications/Docker.app
    fi
fi

# Check if apache2-utils is installed
echo "apache2-utils Installing..."
if [ "$PLATFORM" == "Linux" ]; then
    sudo apt-get update -y
    sudo apt-get install apache2-utils -y
elif [ "$PLATFORM" == "Darwin" ]; then
    brew install apache2-utils
fi

# Determine the directory for project-infra
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
PROJECT_DIR="$PARENT_DIR/fairtrace_v2"

# Clone the repository
REPO_URL="git@git.cied.in:fairfood/trace-v2/backend/fairtrace_v2.git"
BRANCH="master"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Cloning the repository to $PROJECT_DIR..."
    git clone  --single-branch --branch "$BRANCH" "$REPO_URL" "$PROJECT_DIR"
else
    echo "Repository already cloned at $PROJECT_DIR."
fi

#Rename .sample files in the env folder
echo "Renaming .sample files in the env folder..."
find "$SCRIPT_DIR/env" -type f -name "*.sample" | while read -r file; do
    dest="${file%.sample}"
    echo "Renaming: $file -> $dest"
    mv "$file" "$dest"
done

# Rename .sample files in the services/secrets folder
echo "Renaming .sample files in the services/secrets folder..."
find "$SCRIPT_DIR/services/secrets" -type f -name "*.sample" | while read -r file; do
    dest="${file%.sample}"
    echo "Renaming: $file -> $dest"
    mv "$file" "$dest"
done

# Generate .htpasswd for Nginx and replace .htpasswd.sample
echo "Generating .htpasswd for Nginx..."
HTPASSWD_FILE="$SCRIPT_DIR/nginx/.htpasswd"
SAMPLE_HTPASSWD_FILE="$SCRIPT_DIR/nginx/.htpasswd.sample"

if [ -f "$SAMPLE_HTPASSWD_FILE" ]; then
    read -p "Enter username for Nginx: " NGINX_USER
    read -s -p "Enter password for Nginx: " NGINX_PASSWORD
    echo
    if command -v htpasswd &> /dev/null; then
        htpasswd -cb "$HTPASSWD_FILE" "$NGINX_USER" "$NGINX_PASSWORD"
    else
        echo "htpasswd command not found. Installing apache2-utils..."
        if [ "$PLATFORM" == "Linux" ]; then
            sudo apt-get install -y apache2-utils
        elif [ "$PLATFORM" == "Darwin" ]; then
            brew install httpd
        fi
        htpasswd -cb "$HTPASSWD_FILE" "$NGINX_USER" "$NGINX_PASSWORD"
    fi
    echo "Replacing .htpasswd.sample with .htpasswd..."
    rm -f "$SAMPLE_HTPASSWD_FILE"
else
    echo ".htpasswd.sample file not found. Skipping replacement."
fi

echo "✔ Curl"
echo "✔ Git"
echo "✔ Docker"
echo "✔ Apache2-Utils"
echo "✔ Files renamed and .htpasswd generated"
echo "✔ Setup completed successfully."
