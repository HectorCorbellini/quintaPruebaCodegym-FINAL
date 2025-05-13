#!/bin/bash

# Common functions for JiraRush application scripts
# This file should be sourced by other scripts

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

# Build the application
build_application() {
    local skip_tests=$1
    
    echo "Building application..."
    if [ "$skip_tests" = "true" ]; then
        mvn clean package -DskipTests
    else
        mvn clean package
    fi
}

# Run the application with the specified profile
run_application() {
    local profile=$1
    local memory_opts=$2
    
    echo "Starting application in $profile mode..."
    
    if [ -n "$memory_opts" ]; then
        export MAVEN_OPTS="$memory_opts"
    fi
    
    mvn spring-boot:run -Dspring.profiles.active=$profile -Dspring-boot.run.jvmArguments="-Dspring.config.name=application,application-$profile"
    
    # The application is now running in the foreground
    # The script will only reach this point if the application is stopped
    echo "Application has been stopped."
}
