package com.codegym.jira.common.error;

public class DataConflictException extends AppException {
    private static final long serialVersionUID = 1L;
    
    public DataConflictException(String msg) {
        super(msg);
    }
}