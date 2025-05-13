package com.codegym.jira.bugtracking.project;

import com.codegym.jira.bugtracking.Handlers;
import com.codegym.jira.bugtracking.ObjectType;
import com.codegym.jira.common.BaseHandler;
import com.codegym.jira.common.util.Util;
import com.codegym.jira.ref.RefType;
import com.codegym.jira.ref.ReferenceService;
import com.codegym.jira.bugtracking.project.to.ProjectTo;
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
public class ProjectUIController {
    private static final String ATTR_PROJECT = "project";
    private static final String VIEW_PROJECT = "project";
    private static final String VIEW_PROJECT_EDIT = "project-edit";

    private final ProjectMapperFull mapperFull;

    private final Handlers.ProjectHandler handler;
    private final Handlers.AttachmentHandler attachmentHandler;

    @GetMapping("/projects/{id}")
    public String get(@PathVariable long id, @RequestParam(required = false) boolean fragment, Model model) {
        model.addAttribute(ATTR_PROJECT, mapperFull.toTo(Util.checkExist(id, handler.getRepository().findFullById(id))));
        model.addAttribute("fragment", fragment);
        model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(id, ObjectType.PROJECT));
        model.addAttribute("belongs", handler.getAllBelongs(id));
        return VIEW_PROJECT;
    }

    @GetMapping("/mngr/projects/edit/{id}")
    public String edit(@PathVariable long id, Model model) {
        log.info("edit {}", id);
        model.addAttribute(ATTR_PROJECT, handler.getTo(id));
        model.addAttribute("types", ReferenceService.getRefs(RefType.PROJECT));
        model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(id, ObjectType.PROJECT));
        return VIEW_PROJECT_EDIT;
    }

    @GetMapping("/mngr/projects/new")
    public String editFormNew(@RequestParam(required = false) Long parentId, Model model) {
        log.info("editFormNew for task with parentId {}", parentId);
        Project newProject = new Project();
        newProject.setParentId(parentId);
        model.addAttribute(ATTR_PROJECT, handler.getMapper().toTo(newProject));
        model.addAttribute("types", ReferenceService.getRefs(RefType.PROJECT));
        return VIEW_PROJECT_EDIT;
    }

    @PostMapping("/mngr/projects")
    public String createOrUpdate(@Valid @ModelAttribute("project") ProjectTo projectTo, BindingResult result, Model model) {
        if (result.hasErrors()) {
            model.addAttribute("types", ReferenceService.getRefs(RefType.PROJECT));
            if (!projectTo.isNew()) {
                model.addAttribute("attachs", attachmentHandler.getRepository().getAllForObject(projectTo.id(), ObjectType.PROJECT));
            }
            return VIEW_PROJECT_EDIT;
        }
        final Long id;
        if (projectTo.isNew()) {
            Project project = handler.createWithBelong(projectTo, ObjectType.PROJECT, "project_author");
            id = project.getId();
        } else {
            handler.updateFromTo(projectTo, projectTo.id());
            id = projectTo.getId();
        }
        return "redirect:/ui/projects/" + id;
    }
}
