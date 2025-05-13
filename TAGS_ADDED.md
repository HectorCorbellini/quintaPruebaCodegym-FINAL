# Tag Management for Tasks

This document outlines the implementation of tag management functionality for tasks in the Jira-like bug tracking system.

## Overview

The system now supports adding, removing, and managing tags for tasks. Tags are simple strings that can be associated with tasks to provide additional categorization and filtering capabilities.

## Database Schema

The `task_tag` join table has been created with the following structure:
- `task_id` (BIGINT, NOT NULL): Foreign key to the task
- `tag` (VARCHAR(32), NOT NULL): The tag value

A unique constraint exists on the combination of `(task_id, tag)` to prevent duplicate tags per task.

## Service Layer

The `TaskService` class provides the following methods for tag management:

### `Set<String> getTags(long taskId)`
- Retrieves all tags for a specific task
- Returns an empty set if no tags exist
- Throws `NotFoundException` if the task doesn't exist

### `Set<String> addTag(long taskId, String tag)`
- Adds a tag to a task
- Returns the updated set of tags
- Validates that the tag is not null
- Automatically handles duplicate prevention
- Throws `NotFoundException` if the task doesn't exist

### `Set<String> removeTag(long taskId, String tag)`
- Removes a tag from a task
- Returns the updated set of tags
- Validates that the tag is not null
- Is idempotent (no error if tag doesn't exist)
- Throws `NotFoundException` if the task doesn't exist

### `Set<String> setTags(long taskId, Set<String> tags)`
- Replaces all tags for a task
- Validates that the tags set is not null
- Returns the new set of tags
- Throws `NotFoundException` if the task doesn't exist

## REST API

The following endpoints are available at `/api/tasks/{id}/tags`:

### GET `/api/tasks/{id}/tags`
- Retrieves all tags for a task
- Returns: `200 OK` with a JSON array of tag strings
- Example response: `["bug", "high-priority", "backend"]`

### POST `/api/tasks/{id}/tags?tag={tag}`
- Adds a tag to a task
- Parameters:
  - `tag` (required): The tag to add
- Returns: `200 OK` with the updated set of tags
- Example: `POST /api/tasks/123/tags?tag=urgent`

### DELETE `/api/tasks/{id}/tags?tag={tag}`
- Removes a tag from a task
- Parameters:
  - `tag` (required): The tag to remove
- Returns: `200 OK` with the updated set of tags
- Example: `DELETE /api/tasks/123/tags?tag=obsolete`

### PUT `/api/tasks/{id}/tags`
- Replaces all tags for a task
- Request body: JSON array of tag strings
- Returns: `200 OK` with the new set of tags
- Example:
  ```http
  PUT /api/tasks/123/tags
  Content-Type: application/json
  
  ["bug", "high-priority", "frontend"]
  ```

## Validation Rules

1. Tag length must be between 2 and 32 characters
2. Tags are case-sensitive
3. Leading/trailing whitespace is automatically trimmed
4. Empty or blank tags are rejected
5. A task can have multiple tags, but each tag can only appear once per task

## Error Responses

- `404 Not Found`: When the specified task doesn't exist
- `400 Bad Request`: When request validation fails (e.g., missing or invalid parameters)
- `500 Internal Server Error`: For unexpected server errors

## Usage Examples

### Adding a tag
```bash
curl -X POST "http://localhost:8080/api/tasks/123/tags?tag=urgent" \
  -H "Content-Type: application/json"
```

### Removing a tag
```bash
curl -X DELETE "http://localhost:8080/api/tasks/123/tags?tag=obsolete" \
  -H "Content-Type: application/json"
```

### Replacing all tags
```bash
curl -X PUT "http://localhost:8080/api/tasks/123/tags" \
  -H "Content-Type: application/json" \
  -d '["bug", "high-priority", "frontend"]'
```

### Getting all tags
```bash
curl "http://localhost:8080/api/tasks/123/tags"
```

## Implementation Notes

- Tags are stored in a separate join table (`task_tag`) to maintain a many-to-many relationship
- The implementation uses JPA's `@ElementCollection` for simple tag management
- All mutating operations are transactional
- The API follows RESTful principles and the project's existing patterns
