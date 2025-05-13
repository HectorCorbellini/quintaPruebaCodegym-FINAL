#!/bin/bash

# Set up trap to handle errors
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Common functions for JiraRush application scripts

# Check if required tools are installed
check_prerequisites() {
    # Check if Maven is installed
    if ! command -v mvn &> /dev/null; then
        echo "Error: Maven is not installed. Please install Maven first."
        exit 1
    fi

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install Docker first."
        exit 1
    fi
}

# Clean up existing Docker container
cleanup_container() {
    local container_name=$1
    if docker ps -a | grep -q $container_name; then
        echo "Removing existing PostgreSQL container $container_name..."
        docker rm -f $container_name
    fi
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    local container_name=$1
    local db_name=$2
    local db_user=$3
    
    echo "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        docker exec -i $container_name psql -U $db_user -d $db_name -c "SELECT 1;" >/dev/null 2>&1 && break
        echo "Waiting... ($i/30)"
        sleep 1
    done
    
    # Check if PostgreSQL is ready
    if [ $? -ne 0 ]; then
        echo "Error: PostgreSQL container failed to start properly"
        return 1
    fi
    
    return 0
}

# Verify database connection
verify_database() {
    local container_name=$1
    local db_name=$2
    local db_user=$3
    local check_query=$4
    local expected_result=$5
    
    echo "Verifying database connection..."
    if docker exec -i $container_name psql -U $db_user -d $db_name -c "$check_query" | grep -q "$expected_result"; then
        echo "Database verification successful!"
        return 0
    else
        echo "Warning: Database verification failed. Please check the logs."
        return 1
    fi
}

# Clean up processes using specific ports
cleanup_ports() {
    echo "Cleaning up processes on specified ports..."
    for port in "$@"; do
        echo "Checking port $port..."
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
            echo "Killing processes on port $port..."
            lsof -Pi :$port -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
        fi
    done
    
    # Wait a bit for processes to terminate
    sleep 2
    
    # Double check if ports are still in use
    for port in "$@"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
            echo "Warning: Port $port is still in use after cleanup."
            echo "Processes using port $port:"
            lsof -Pi :$port -sTCP:LISTEN
            echo "Attempting to force cleanup..."
            # Try a more aggressive cleanup
            fuser -k $port/tcp || true
            sleep 2
        fi
    done
}

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running. Starting Docker service..."
    if ! service docker start; then
        echo "Failed to start Docker service. Please start Docker manually."
        exit 1
    fi
    echo "Waiting for Docker to be ready..."
    sleep 5
fi

# Restart Docker to ensure clean state
echo "Restarting Docker to ensure clean state..."
service docker restart
echo "Waiting for Docker to be ready after restart..."
sleep 10

# Check prerequisites
check_prerequisites

# Clean up existing container
cleanup_container "jira-postgres"

# Clean up any processes using our ports
cleanup_ports 5432 5433 8080

# Clean up Docker networks to prevent networking issues
echo "Cleaning up Docker networks..."
docker network prune -f

# Create data directory if it doesn't exist
mkdir -p ./pgdata || {
    echo "Failed to create data directory. Check permissions."
    exit 1
}

# Start PostgreSQL container
echo "Starting PostgreSQL container..."
docker run --name jira-postgres \
    -e POSTGRES_USER=jira \
    -e POSTGRES_PASSWORD=CodeGymJira \
    -e POSTGRES_DB=jira \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v $(pwd)/pgdata:/var/lib/postgresql/data \
    -p 5432:5432 \
    -d \
    --dns 8.8.8.8 \
    postgres:13

# Check if container started successfully
if ! docker ps | grep -q "jira-postgres"; then
    echo "Error: Failed to start PostgreSQL container"
    exit 1
fi

# Wait for PostgreSQL to be ready
wait_for_postgres "jira-postgres" "jira" "jira" || {
    echo "Error: PostgreSQL failed to start properly"
    cleanup_container "jira-postgres"
    exit 1
}

# NOTE: Database initialization is now handled by the application through Liquibase
# This script only sets up the PostgreSQL container
# The application will initialize the schema when it starts

# Create an empty database ready for the application to initialize
echo "Setting up empty database for application initialization..."

# Verify database connection
verify_database "jira-postgres" "jira" "jira" "SELECT 1" "1"

echo "Database container is ready! The application will initialize the schema on startup."
