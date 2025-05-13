package com.codegym.jira.common.error;

import org.springframework.lang.NonNull;

public class AppException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AppException(@NonNull String message) {
        super(message);
    }
}
