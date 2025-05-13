package com.codegym.jira.common.error;

public class IllegalRequestDataException extends AppException {
    private static final long serialVersionUID = 1L;
    
    public IllegalRequestDataException(String msg) {
        super(msg);
    }
}