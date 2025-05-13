package com.codegym.jira.bugtracking.task.to;

import com.codegym.jira.common.util.validation.Code;
import com.codegym.jira.common.util.validation.Description;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.annotation.Nullable;
import jakarta.validation.constraints.Positive;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;
import java.util.Objects;

@Getter
@Setter
@EqualsAndHashCode(callSuper = true)
public class TaskToExt extends TaskTo {
    @Description
    String description;

    @Code
    String priorityCode;

    @Nullable
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    LocalDateTime updated;

    @Nullable
    @Positive
    Integer estimate;

    public TaskToExt(Long id, String code, String title, String description, String typeCode, String statusCode, String priorityCode,
                     LocalDateTime updated, Integer estimate, Long parentId, long projectId, Long sprintId) {
        super(id, code, title, typeCode, statusCode, parentId, projectId, sprintId);
        this.description = description;
        this.priorityCode = priorityCode;
        this.updated = updated;
        this.estimate = estimate;
    }


}
