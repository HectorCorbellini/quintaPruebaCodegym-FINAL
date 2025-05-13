package com.codegym.jira.common.internal.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

/**
 * Configuración para Spring Boot Actuator.
 * Carga las propiedades específicas de Actuator desde el archivo actuator.properties.
 */
@Configuration
@PropertySource("classpath:actuator.properties")
public class ActuatorConfig {
    // La configuración se realiza a través del archivo de propiedades
}
