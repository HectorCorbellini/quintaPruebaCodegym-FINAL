package com.codegym.jira.bugtracking.sprint;

import com.codegym.jira.bugtracking.Handlers;
import com.codegym.jira.bugtracking.ObjectType;
import com.codegym.jira.common.BaseHandler;
import com.codegym.jira.bugtracking.project.ProjectRepository;
import com.codegym.jira.bugtracking.sprint.to.SprintTo;
import jakarta.annotation.Nullable;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;

import static com.codegym.jira.common.BaseHandler.createdResponse;

@RestController
@Validated
@RequestMapping(value = BaseHandler.REST_URL, produces = MediaType.APPLICATION_JSON_VALUE)
@RequiredArgsConstructor
@Slf4j
public class SprintController {
    private final ProjectRepository projectRepository;

    private final Handlers.SprintHandler handler;

    @GetMapping("/sprints/{id}")
    public SprintTo get(@PathVariable long id) {
        return handler.getTo(id);
    }

    @GetMapping("/sprints/by-project")
    public List<SprintTo> getAllByProject(@RequestParam long projectId, @RequestParam @Nullable Boolean enabled) {
        log.info("get all for project {} and enabled {}", projectId, enabled);
        checkProjectExists(projectId);
        return handler.getMapper().toToList(
                !Boolean.TRUE.equals(enabled) ?
                        handler.getRepository().getAllByProject(projectId) :
                        handler.getRepository().getAllEnabledByProject(projectId)
        );
    }

    private void checkProjectExists(long id) {
        projectRepository.getExisted(id);
    }

    @GetMapping("/sprints/by-project-and-status")
    public List<Sprint> getAllByProjectAndStatus(@RequestParam long projectId, @NotBlank @RequestParam String statusCode) {
        log.info("get all {} sprints for project with id={}", statusCode, projectId);
        checkProjectExists(projectId);
        return handler.getRepository().getAllByProjectAndStatus(projectId, statusCode);
    }

    @PostMapping(path = "/mngr/sprints", consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<Sprint> createWithLocation(@Valid @RequestBody SprintTo sprintTo) {
        Sprint created = handler.createWithBelong(sprintTo, ObjectType.SPRINT, "sprint_author");
        return BaseHandler.createdResponse(BaseHandler.REST_URL + "/sprints", created);
    }

    @PutMapping(path = "/mngr/sprints/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@Validated @RequestBody SprintTo sprintTo, @PathVariable long id) {
        handler.updateFromTo(sprintTo, id);
    }

    @Transactional
    @PatchMapping("/mngr/sprints/{id}/change-status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void changeStatusCode(@PathVariable long id, @RequestParam String statusCode) {
        log.info("change statusCode of sprint {}", id);
        Sprint sprint = handler.getRepository().getExisted(id);
        sprint.setStatusCode(statusCode);
    }

    @PatchMapping("/mngr/sprints/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void enable(@PathVariable long id, @RequestParam boolean enabled) {
        handler.enable(id, enabled);
    }
}
