package com.codegym.jira.bugtracking.project.to;

import com.codegym.jira.common.to.CodeTo;
import lombok.EqualsAndHashCode;
import lombok.Value;

@Value
@EqualsAndHashCode(callSuper = true)
public class ProjectToFull extends ProjectTo {
    CodeTo parent;

    public ProjectToFull(Long id, String code, String title, String description, String typeCode, CodeTo parent) {
        super(id, code, title, description, typeCode, parent == null ? null : parent.getId());
        this.parent = parent;
    }
}