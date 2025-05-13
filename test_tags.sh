#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Variables
BASE_URL="http://localhost:8080"
API_URL="${BASE_URL}/api"
AUTH_HEADER=""
TEST_TASK_ID="92"
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

# Functions
success() {
    echo -e "${GREEN}✓ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

error() {
    echo -e "${RED}✗ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

subsection() {
    echo -e "\n${PURPLE}--- $1 ---${NC}"
}

# Login function
do_login() {
    info "Iniciando sesión con usuario: admin@gmail.com usando autenticación básica"
    AUTH_HEADER="Authorization: Basic $(echo -n "admin@gmail.com:admin" | base64)"
    
    # Verify login
    api_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/profile")
    if [[ $api_response == *"\"id\""* ]]; then
        success "Login exitoso con admin@gmail.com usando autenticación básica"
        return 0
    else
        error "Fallo al iniciar sesión con admin@gmail.com"
        return 1
    fi
}

# Test tag functionality
test_tags() {
    subsection "Pruebas de Etiquetas (Tags)"
    
    # Test 1: Get initial tags
    info "Obteniendo etiquetas iniciales para la tarea ${TEST_TASK_ID}..."
    INITIAL_TAGS=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    echo "Etiquetas iniciales: $INITIAL_TAGS"
    
    # Test 2: Add a tag
    info "Añadiendo etiqueta 'test-tag' a la tarea ${TEST_TASK_ID}..."
    ADD_RESULT=$(curl -s -H "$AUTH_HEADER" -X POST "${API_URL}/tasks/${TEST_TASK_ID}/tags?tag=test-tag")
    if [[ $ADD_RESULT == *"test-tag"* ]]; then
        success "Etiqueta 'test-tag' añadida correctamente"
    else
        error "Fallo al añadir etiqueta 'test-tag'"
    fi
    
    # Test 3: Verify tag was added
    info "Verificando que la etiqueta fue añadida..."
    AFTER_ADD=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    if [[ $AFTER_ADD == *"test-tag"* ]]; then
        success "Etiqueta 'test-tag' verificada en la tarea"
    else
        error "Etiqueta 'test-tag' no encontrada en la tarea"
    fi
    
    # Test 4: Add another tag
    info "Añadiendo otra etiqueta 'priority-high' a la tarea ${TEST_TASK_ID}..."
    ADD_RESULT2=$(curl -s -H "$AUTH_HEADER" -X POST "${API_URL}/tasks/${TEST_TASK_ID}/tags?tag=priority-high")
    if [[ $ADD_RESULT2 == *"priority-high"* ]]; then
        success "Etiqueta 'priority-high' añadida correctamente"
    else
        error "Fallo al añadir etiqueta 'priority-high'"
    fi
    
    # Test 5: Set all tags (replace)
    info "Reemplazando todas las etiquetas con ['bug', 'frontend']..."
    SET_RESULT=$(curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" -X PUT -d '["bug", "frontend"]' "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    if [[ $SET_RESULT == *"bug"* && $SET_RESULT == *"frontend"* ]]; then
        success "Etiquetas reemplazadas correctamente"
    else
        error "Fallo al reemplazar etiquetas"
    fi
    
    # Test 6: Remove a tag
    info "Eliminando etiqueta 'frontend' de la tarea ${TEST_TASK_ID}..."
    REMOVE_RESULT=$(curl -s -H "$AUTH_HEADER" -X DELETE "${API_URL}/tasks/${TEST_TASK_ID}/tags?tag=frontend")
    if [[ $REMOVE_RESULT != *"frontend"* && $REMOVE_RESULT == *"bug"* ]]; then
        success "Etiqueta 'frontend' eliminada correctamente"
    else
        error "Fallo al eliminar etiqueta 'frontend'"
    fi
    
    # Test 7: Final state
    info "Estado final de etiquetas para la tarea ${TEST_TASK_ID}..."
    FINAL_TAGS=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    echo "Etiquetas finales: $FINAL_TAGS"
    
    # Clean up - restore original state
    info "Limpiando (restaurando estado original)..."
    CLEANUP=$(curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" -X PUT -d "$INITIAL_TAGS" "${API_URL}/tasks/${TEST_TASK_ID}/tags")
    if [[ "$CLEANUP" == "$INITIAL_TAGS" ]]; then
        success "Estado original restaurado correctamente"
    else
        error "Fallo al restaurar estado original"
    fi
}

# Main execution
section "PRUEBAS DE FUNCIONALIDAD DE ETIQUETAS (TAGS)"

# Check if service is available
info "Verificando disponibilidad de ${BASE_URL}..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}")
if [[ $HTTP_CODE == "200" ]]; then
    success "Servicio disponible en ${BASE_URL} (HTTP ${HTTP_CODE})"
else
    error "Servicio no disponible en ${BASE_URL} (HTTP ${HTTP_CODE})"
    exit 1
fi

# Login
do_login
if [[ $? -ne 0 ]]; then
    error "No se pudo iniciar sesión. Abortando pruebas."
    exit 1
fi

# Run tag tests
test_tags

# Summary
section "RESUMEN DE PRUEBAS DE ETIQUETAS"
echo "Total de pruebas: $TOTAL_TESTS"
echo "Pruebas exitosas: $PASSED_TESTS"
echo "Pruebas fallidas: $FAILED_TESTS"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}✓ TODAS LAS PRUEBAS DE ETIQUETAS COMPLETADAS EXITOSAMENTE${NC}"
else
    echo -e "${RED}✗ ALGUNAS PRUEBAS DE ETIQUETAS FALLARON${NC}"
fi
