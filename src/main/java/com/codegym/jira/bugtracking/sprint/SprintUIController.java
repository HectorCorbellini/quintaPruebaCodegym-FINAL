package com.codegym.jira.bugtracking.sprint;

import com.codegym.jira.bugtracking.Handlers;
import com.codegym.jira.bugtracking.ObjectType;
import com.codegym.jira.common.BaseHandler;
import com.codegym.jira.common.util.Util;
import com.codegym.jira.ref.RefType;
import com.codegym.jira.ref.ReferenceService;
import com.codegym.jira.bugtracking.project.ProjectRepository;
import com.codegym.jira.bugtracking.sprint.to.SprintTo;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

@Slf4j
@Controller
@RequestMapping(BaseHandler.UI_URL)
@RequiredArgsConstructor
public class SprintUIController {
    private static final String ATTR_SPRINT = "sprint";
    private static final String VIEW_SPRINT = "sprint";
    private static final String VIEW_SPRINT_EDIT = "sprint-edit";

    private final SprintMapperFull mapperFull;

    private final Handlers.SprintHandler handler;
    private final Handlers.AttachmentHandler attachmentHandler;

    private final ProjectRepository projectRepository;

    @GetMapping("/sprints/{id}")
    public String get(@PathVariable long id, @RequestParam(required = false) boolean fragment, Model model) {
        log.info("get {}", id);
        model.addAttribute(ATTR_SPRINT, mapperFull.toTo(Util.checkExist(id, handler.getRepository().findFullById(id))));
        model.addAttribute("fragment", fragment);
        model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(id, ObjectType.SPRINT));
        model.addAttribute("belongs", handler.getAllBelongs(id));
        return VIEW_SPRINT;
    }

    @GetMapping("/mngr/sprints/edit/{id}")
    public String edit(@PathVariable long id, Model model) {
        log.info("edit {}", id);
        model.addAttribute(ATTR_SPRINT, handler.getTo(id));
        model.addAttribute("statuses", ReferenceService.getRefs(RefType.SPRINT_STATUS));
        model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(id, ObjectType.SPRINT));
        return VIEW_SPRINT_EDIT;
    }

    @GetMapping("/mngr/sprints/new")
    public String editFormNew(@RequestParam long projectId, Model model) {
        log.info("editFormNew for sprint with project {}", projectId);
        Sprint newSprint = new Sprint();
        newSprint.setProjectId(projectId);
        model.addAttribute(ATTR_SPRINT, handler.getMapper().toTo(newSprint));
        model.addAttribute("statuses", ReferenceService.getRefs(RefType.SPRINT_STATUS));
        return VIEW_SPRINT_EDIT;
    }

    @PostMapping("/mngr/sprints")
    public String createOrUpdate(@Valid @ModelAttribute("sprint") SprintTo sprintTo, BindingResult result, Model model) {
        if (result.hasErrors()) {
            model.addAttribute("statuses", ReferenceService.getRefs(RefType.SPRINT_STATUS));
            if (!sprintTo.isNew()) {
                model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(sprintTo.id(), ObjectType.SPRINT));
            }
            return VIEW_SPRINT_EDIT;
        }
        final Long id;
        if (sprintTo.isNew()) {
            id = handler.createWithBelong(sprintTo, ObjectType.SPRINT, "sprint_author").id();
        } else {
            handler.updateFromTo(sprintTo, sprintTo.id());
            id = sprintTo.getId();
        }
        return "redirect:/ui/sprints/" + id;
    }
}
