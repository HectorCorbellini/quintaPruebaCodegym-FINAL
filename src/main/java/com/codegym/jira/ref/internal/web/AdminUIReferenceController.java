package com.codegym.jira.ref.internal.web;

import com.codegym.jira.ref.RefType;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

/**
 * Controller for the admin UI reference page.
 */
@Slf4j
@Controller
@RequestMapping(value = AdminUIReferenceController.URL)
public class AdminUIReferenceController {
    static final String URL = "/ui/admin/references";

    @GetMapping
    public String getRefTypes(Model model) {
        model.addAttribute("refTypes", RefType.values()); // No PMD issues: values() is required here
        return "references";
    }
}
