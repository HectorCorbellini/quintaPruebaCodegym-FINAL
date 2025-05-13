# CodeGym JIRA Clone

A Spring Boot-based project management application inspired by JIRA. This application provides issue tracking, project management, and team collaboration features.

## Features

- User authentication (local and OAuth2 with GitHub, Google, GitLab)
- Project and task management
- Task assignment and tracking
- Activity logging and time tracking
- Tag management for tasks
- File attachments
- RESTful API

## Technology Stack

- Java 17
- Spring Boot 3.0.2
- Spring Security with OAuth2
- Spring Data JPA
- PostgreSQL
- Thymeleaf
- Liquibase for database migrations
- Maven
- PMD for static code analysis
- Spring Boot Actuator for health checks and monitoring

## Getting Started

### Prerequisites

- JDK 17 or higher
- Maven 3.6+
- PostgreSQL
- Docker (optional, for containerized database)

### Running the Application

#### Development Mode

```bash
./run_app_dev.sh
```

Or manually:

```bash
echo "2" | ./run_app_no_pmd.sh
```

#### Production Mode

```bash
echo "1" | ./run_app_no_pmd.sh
```

### Database Configuration

```
url: jdbc:postgresql://localhost:5432/jira
username: jira
password: CodeGymJira
```

## API Documentation

API documentation is available at [http://localhost:8080/doc](http://localhost:8080/doc) when the application is running.

## Project Structure

The project follows a modular architecture based on Spring Modulith:
- Login module - Authentication and user management
- Profile module - User profiles
- Bugtracking module - Issue tracking and management
- Common module - Shared utilities and configurations

## Recent Improvements

- Task time tracking implementation
- Tag management for tasks
- Modern file handling with Java NIO
- Enhanced security with secrets management
- Optimized Spring Boot Actuator configuration

For a detailed list of improvements and setup instructions, see [ADDINGS.md](ADDINGS.md)

## Testing

The project includes automated tests and a comprehensive test script:

```bash
./strong_test_app.sh
```

## License

This project is licensed under the MIT License.