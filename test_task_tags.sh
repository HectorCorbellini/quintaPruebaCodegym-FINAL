#!/bin/bash

# Función para probar etiquetas de tareas
test_task_tags() {
    subsection "Pruebas de Etiquetas (Tags)"
    
    if [[ -z "$TEST_TASK_ID" ]]; then
        info "No hay ID de tarea disponible para pruebas de etiquetas"
        return 0
    fi
    
    # Obtener etiquetas iniciales
    initial_tags=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    
    # Añadir una etiqueta
    add_tag_response=$(curl -s -H "$AUTH_HEADER" -X POST "${API_URL}/tasks/${TEST_TASK_ID}/tags?tag=test-tag")
    if [[ $add_tag_response == *"test-tag"* ]]; then
        success "Añadir etiqueta a tarea exitoso"
    else
        error "Fallo al añadir etiqueta a tarea"
    fi
    
    # Verificar que la etiqueta fue añadida
    verify_tags=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    if [[ $verify_tags == *"test-tag"* ]]; then
        success "Verificación de etiqueta añadida exitosa"
    else
        error "Fallo al verificar etiqueta añadida"
    fi
    
    # Reemplazar todas las etiquetas
    set_tags_response=$(curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" -X PUT -d '["bug", "frontend"]' "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    if [[ $set_tags_response == *"bug"* && $set_tags_response == *"frontend"* ]]; then
        success "Reemplazo de etiquetas exitoso"
    else
        error "Fallo al reemplazar etiquetas"
    fi
    
    # Eliminar una etiqueta
    remove_tag_response=$(curl -s -H "$AUTH_HEADER" -X DELETE "${API_URL}/tasks/${TEST_TASK_ID}/tags?tag=frontend")
    if [[ $remove_tag_response != *"frontend"* ]]; then
        success "Eliminación de etiqueta exitosa"
    else
        error "Fallo al eliminar etiqueta"
    fi
    
    # Restaurar estado original
    curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" -X PUT -d "$initial_tags" "${API_URL}/tasks/${TEST_TASK_ID}/tags" > /dev/null
}
