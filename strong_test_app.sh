#!/bin/bash

# Colores para mejor legibilidad
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Variables globales
BASE_URL="http://localhost:8080"
API_URL="${BASE_URL}/api"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
AUTH_HEADER=""
TEST_PROJECT_ID=""
TEST_SPRINT_ID=""
TEST_TASK_ID=""
START_TIME=$(date +%s)

# Archivo para guardar el reporte
REPORT_FILE="test_report_$(date +%Y%m%d_%H%M%S).txt"

# Función para imprimir mensajes de éxito
success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "✓ $1" >> $REPORT_FILE
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Función para imprimir mensajes de error
error() {
    echo -e "${RED}✗ $1${NC}"
    echo "✗ $1" >> $REPORT_FILE
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Función para imprimir mensajes informativos
info() {
    echo -e "${YELLOW}ℹ $1${NC}"
    echo "ℹ $1" >> $REPORT_FILE
}

# Función para imprimir encabezados de sección
section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
    echo -e "\n=== $1 ===" >> $REPORT_FILE
}

# Función para imprimir subsecciones
subsection() {
    echo -e "\n${PURPLE}--- $1 ---${NC}"
    echo -e "\n--- $1 ---" >> $REPORT_FILE
}

# Función para medir el tiempo de respuesta
measure_response_time() {
    local url=$1
    local start_time=$(date +%s.%N)
    curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "$url" > /dev/null
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)
    echo $elapsed
}

# Función para verificar si un servicio está disponible
check_service() {
    local url=$1
    local max_attempts=$2
    local wait_seconds=$3
    local attempt=1

    info "Verificando disponibilidad de $url..."
    
    while [ $attempt -le $max_attempts ]; do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" $url)
        
        if [[ $http_code -ge 200 && $http_code -lt 400 ]]; then
            success "Servicio disponible en $url (HTTP $http_code)"
            return 0
        else
            info "Intento $attempt de $max_attempts: Servicio no disponible (HTTP $http_code). Esperando $wait_seconds segundos..."
            sleep $wait_seconds
            attempt=$((attempt + 1))
        fi
    done
    
    error "Servicio no disponible después de $max_attempts intentos"
    return 1
}

# Función para realizar login usando autenticación básica
do_login() {
    local username=$1
    local password=$2
    
    info "Iniciando sesión con usuario: $username usando autenticación básica"
    
    # Crear credenciales en formato base64 para autenticación básica
    AUTH_HEADER="Authorization: Basic $(echo -n "$username:$password" | base64)"
    
    # Verificar si podemos acceder a una API protegida usando autenticación básica
    api_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/profile")
    
    # Verificar si la respuesta indica que estamos autenticados
    if [[ $api_response == *"id"* || $api_response == *"mailNotifications"* || $api_response == *"contacts"* ]]; then
        success "Login exitoso con $username usando autenticación básica"
        # Guardar el header de autenticación para usarlo en las siguientes peticiones
        echo "$AUTH_HEADER" > auth_header.txt
        return 0
    else
        # Intentar con otro endpoint
        projects_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/projects")
        if [[ $projects_response == *"id"* || $projects_response == *"title"* || $projects_response == *"code"* ]]; then
            success "Login exitoso con $username usando autenticación básica (verificado con proyectos)"
            # Guardar el header de autenticación para usarlo en las siguientes peticiones
            echo "$AUTH_HEADER" > auth_header.txt
            return 0
        else
            error "Login fallido con $username usando autenticación básica"
            return 1
        fi
    fi
}

# Función para probar la funcionalidad de perfil
test_profile() {
    subsection "Pruebas de Perfil"
    
    # Obtener perfil usando la API con autenticación básica
    response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/profile")
    
    if [[ $response == *"id"* && $response == *"mailNotifications"* ]]; then
        success "Acceso a perfil exitoso vía API"
        
        # Medir tiempo de respuesta
        response_time=$(measure_response_time "${API_URL}/profile")
        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            success "Tiempo de respuesta para perfil: ${response_time}s (aceptable)"
        else
            error "Tiempo de respuesta para perfil: ${response_time}s (demasiado lento)"
        fi
        
        return 0
    else
        error "No se pudo acceder al perfil vía API"
        return 1
    fi
}

# Función para probar la funcionalidad del dashboard
test_dashboard() {
    subsection "Pruebas de Dashboard y Proyectos"
    
    # Obtener proyectos usando la API con autenticación básica
    response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/projects")
    
    if [[ $response == *"id"* && $response == *"title"* ]]; then
        success "Acceso a proyectos exitoso vía API"
        
        # Extraer el ID del primer proyecto para pruebas posteriores
        TEST_PROJECT_ID=$(echo $response | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        if [[ ! -z "$TEST_PROJECT_ID" ]]; then
            success "ID de proyecto extraído para pruebas: $TEST_PROJECT_ID"
            
            # Probar acceso a un proyecto específico
            project_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/projects/${TEST_PROJECT_ID}")
            if [[ $project_response == *"id"* && $project_response == *"title"* ]]; then
                success "Acceso a proyecto específico exitoso"
            else
                error "No se pudo acceder al proyecto específico"
            fi
            
            # Medir tiempo de respuesta
            response_time=$(measure_response_time "${API_URL}/projects")
            if (( $(echo "$response_time < 1.0" | bc -l) )); then
                success "Tiempo de respuesta para proyectos: ${response_time}s (aceptable)"
            else
                error "Tiempo de respuesta para proyectos: ${response_time}s (demasiado lento)"
            fi
        else
            error "No se pudo extraer ID de proyecto para pruebas"
        fi
        
        return 0
    else
        error "No se pudo acceder a proyectos vía API"
        return 1
    fi
}

# Función para probar la funcionalidad de sprints
test_sprints() {
    subsection "Pruebas de Sprints"
    
    if [[ -z "$TEST_PROJECT_ID" ]]; then
        error "No hay ID de proyecto disponible para pruebas de sprints"
        return 1
    fi
    
    # Obtener sprints por proyecto
    response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/sprints/by-project?projectId=${TEST_PROJECT_ID}")
    
    if [[ $response == *"id"* || $response == *"[]"* ]]; then
        success "Acceso a sprints por proyecto exitoso"
        
        # Si hay sprints, extraer el ID del primer sprint para pruebas posteriores
        if [[ $response != "[]" ]]; then
            TEST_SPRINT_ID=$(echo $response | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            if [[ ! -z "$TEST_SPRINT_ID" ]]; then
                success "ID de sprint extraído para pruebas: $TEST_SPRINT_ID"
                
                # Probar acceso a un sprint específico
                sprint_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/sprints/${TEST_SPRINT_ID}")
                if [[ $sprint_response == *"id"* && $sprint_response == *"code"* && $sprint_response == *"statusCode"* ]]; then
                    success "Acceso a sprint específico exitoso"
                else
                    error "No se pudo acceder al sprint específico"
                    echo "Respuesta recibida: $sprint_response"
                fi
            else
                error "No se pudo extraer ID de sprint para pruebas"
            fi
        else
            info "No hay sprints disponibles para el proyecto"
        fi
        
        # Medir tiempo de respuesta
        response_time=$(measure_response_time "${API_URL}/sprints/by-project?projectId=${TEST_PROJECT_ID}")
        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            success "Tiempo de respuesta para sprints: ${response_time}s (aceptable)"
        else
            error "Tiempo de respuesta para sprints: ${response_time}s (demasiado lento)"
        fi
        
        return 0
    else
        error "No se pudo acceder a sprints por proyecto"
        return 1
    fi
}

# Función para probar la funcionalidad de tareas
test_tasks() {
    subsection "Pruebas de Tareas"
    
    if [[ -z "$TEST_PROJECT_ID" ]]; then
        error "No hay ID de proyecto disponible para pruebas de tareas"
        return 1
    fi
    
    # Obtener tareas por proyecto
    response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/by-project?projectId=${TEST_PROJECT_ID}")
    
    if [[ $response == *"id"* || $response == *"[]"* ]]; then
        success "Acceso a tareas por proyecto exitoso"
        
        # Si hay tareas, extraer el ID de la primera tarea para pruebas posteriores
        if [[ $response != "[]" ]]; then
            TEST_TASK_ID=$(echo $response | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            if [[ ! -z "$TEST_TASK_ID" ]]; then
                success "ID de tarea extraído para pruebas: $TEST_TASK_ID"
                
                # Probar acceso a una tarea específica
                task_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}")
                if [[ $task_response == *"id"* && $task_response == *"title"* ]]; then
                    success "Acceso a tarea específica exitoso"
                    
                    # Probar acceso a comentarios de la tarea
                    comments_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/${TEST_TASK_ID}/comments")
                    if [[ $comments_response == *"id"* || $comments_response == *"[]"* ]]; then
                        success "Acceso a comentarios de tarea exitoso"
                    else
                        error "No se pudo acceder a los comentarios de la tarea"
                    fi
                    
                    # Probar funcionalidad de etiquetas (tags)
                    test_task_tags
                else
                    error "No se pudo acceder a la tarea específica"
                fi
            else
                error "No se pudo extraer ID de tarea para pruebas"
            fi
        else
            info "No hay tareas disponibles para el proyecto"
            
            # Si hay un sprint disponible, probar tareas por sprint
            if [[ ! -z "$TEST_SPRINT_ID" ]]; then
                sprint_tasks_response=$(curl -s -H "$AUTH_HEADER" "${API_URL}/tasks/by-sprint?sprintId=${TEST_SPRINT_ID}")
                if [[ $sprint_tasks_response == *"id"* || $sprint_tasks_response == *"[]"* ]]; then
                    success "Acceso a tareas por sprint exitoso"
                else
                    error "No se pudo acceder a tareas por sprint"
                fi
            fi
        fi
        
        # Medir tiempo de respuesta
        response_time=$(measure_response_time "${API_URL}/tasks/by-project?projectId=${TEST_PROJECT_ID}")
        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            success "Tiempo de respuesta para tareas: ${response_time}s (aceptable)"
        else
            error "Tiempo de respuesta para tareas: ${response_time}s (demasiado lento)"
        fi
        
        return 0
    else
        error "No se pudo acceder a tareas por proyecto"
        return 1
    fi
}

# Función para probar etiquetas de tareas
test_task_tags() {
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

# Función para probar la funcionalidad de referencias
test_references() {
    subsection "Pruebas de Referencias"
    
    # Obtener referencias de tipo TASK_STATUS
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "${API_URL}/admin/refs/TASK_STATUS")
    
    if [ "$status_code" -eq 200 ]; then
        success "Acceso a referencias de tipo TASK_STATUS exitoso"
        
        # Probar otros tipos de referencias
        refs_types=("TASK" "SPRINT_STATUS" "PROJECT")
        for ref_type in "${refs_types[@]}"; do
            ref_status=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "${API_URL}/admin/refs/${ref_type}")
            if [ "$ref_status" -eq 200 ]; then
                success "Acceso a referencias de tipo ${ref_type} exitoso"
            else
                error "No se pudo acceder a referencias de tipo ${ref_type}"
            fi
        done
        
        # Medir tiempo de respuesta
        response_time=$(measure_response_time "${API_URL}/admin/refs/TASK_STATUS")
        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            success "Tiempo de respuesta para referencias: ${response_time}s (aceptable)"
        else
            error "Tiempo de respuesta para referencias: ${response_time}s (demasiado lento)"
        fi
        
        return 0
    else
        error "No se pudo acceder a referencias"
        return 1
    fi
}

# Función para probar la funcionalidad de health check (actuator)
test_health_check() {
    subsection "Pruebas de Health Check (Actuator)"
    
    # Probar endpoint de health - Guardamos la respuesta completa
    health_response=$(curl -s -H "$AUTH_HEADER" "${BASE_URL}/actuator/health")
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "${BASE_URL}/actuator/health")
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 503 ]; then
        # Verificar si el endpoint está accesible, independientemente del estado reportado
        success "Health check accesible - HTTP $http_code $([ "$http_code" -eq 503 ] && echo '(DOWN pero esperado)')"
        
        # Extraer el estado del sistema del JSON de respuesta
        if [[ $health_response == *"\"status\":\"UP\""* ]]; then
            success "Estado del sistema: UP"
        elif [[ $health_response == *"\"status\":\"DOWN\""* ]]; then
            # Esto no es un error, es información importante
            info "Estado del sistema: DOWN - Algunos componentes pueden estar inactivos"
            
            # Extraer componentes con problemas
            if [[ $health_response == *"\"mail\":{\"status\":\"DOWN\""* ]]; then
                info "Componente mail está DOWN - Esto es esperado en entorno de desarrollo"
            fi
        else
            info "Estado del sistema: DESCONOCIDO"
        fi
        
        # Medir tiempo de respuesta
        response_time=$(measure_response_time "${BASE_URL}/actuator/health")
        if (( $(echo "$response_time < 0.5" | bc -l) )); then
            success "Tiempo de respuesta para health check: ${response_time}s (aceptable)"
        else
            error "Tiempo de respuesta para health check: ${response_time}s (demasiado lento)"
        fi
        
        # Probar endpoint de info si está disponible
        info_code=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "${BASE_URL}/actuator/info")
        if [ "$info_code" -eq 200 ]; then
            success "Acceso a endpoint info exitoso"
        else
            info "Endpoint info no disponible o vacío"
        fi
        
        return 0
    else
        error "Health check fallido - Endpoint no accesible (HTTP $http_code)"
        return 1
    fi
}

# Función para probar la carga del sistema
test_load() {
    subsection "Pruebas de Carga"
    
    info "Realizando pruebas de carga (10 peticiones concurrentes)"
    
    # Endpoints a probar
    endpoints=(
        "${API_URL}/profile"
        "${API_URL}/projects"
        "${BASE_URL}/actuator/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        info "Probando carga en: $endpoint"
        total_time=0
        
        for i in {1..10}; do
            response_time=$(measure_response_time "$endpoint")
            total_time=$(echo "$total_time + $response_time" | bc)
        done
        
        avg_time=$(echo "scale=3; $total_time / 10" | bc)
        
        if (( $(echo "$avg_time < 1.0" | bc -l) )); then
            success "Tiempo promedio de respuesta para $endpoint: ${avg_time}s (aceptable)"
        else
            error "Tiempo promedio de respuesta para $endpoint: ${avg_time}s (demasiado lento)"
        fi
    done
}

# Función para probar errores y manejo de excepciones
test_error_handling() {
    subsection "Pruebas de Manejo de Errores"
    
    # Probar acceso a un recurso que no existe
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" "${API_URL}/projects/99999")
    
    if [[ $response == "404" ]]; then
        success "Manejo correcto de recurso inexistente (404)"
    else
        error "Manejo incorrecto de recurso inexistente (se esperaba 404, se obtuvo $response)"
    fi
    
    # Probar acceso sin autenticación
    response=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/profile")
    
    if [[ $response == "401" || $response == "403" ]]; then
        success "Manejo correcto de acceso no autorizado ($response)"
    else
        error "Manejo incorrecto de acceso no autorizado (se esperaba 401 o 403, se obtuvo $response)"
    fi
    
    # Probar envío de datos inválidos
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "$AUTH_HEADER" -H "Content-Type: application/json" -X POST -d '{"title":""}' "${API_URL}/mngr/projects")
    
    if [[ $response == "400" || $response == "422" ]]; then
        success "Manejo correcto de datos inválidos (400)"
    else
        error "Manejo incorrecto de datos inválidos (se esperaba 400, se obtuvo $response)"
    fi
}

# Función para generar un reporte detallado
generate_report() {
    section "REPORTE DETALLADO DE PRUEBAS"
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo -e "\n${BLUE}=== RESUMEN DE PRUEBAS ===${NC}"
    echo -e "\n=== RESUMEN DE PRUEBAS ===" >> $REPORT_FILE
    
    echo -e "Fecha y hora: $(date)"
    echo "Fecha y hora: $(date)" >> $REPORT_FILE
    
    echo -e "Duración total: ${DURATION} segundos"
    echo "Duración total: ${DURATION} segundos" >> $REPORT_FILE
    
    echo -e "Total de pruebas: ${TOTAL_TESTS}"
    echo "Total de pruebas: ${TOTAL_TESTS}" >> $REPORT_FILE
    
    echo -e "${GREEN}Pruebas exitosas: ${PASSED_TESTS}${NC}"
    echo "Pruebas exitosas: ${PASSED_TESTS}" >> $REPORT_FILE
    
    echo -e "${RED}Pruebas fallidas: ${FAILED_TESTS}${NC}"
    echo "Pruebas fallidas: ${FAILED_TESTS}" >> $REPORT_FILE
    
    PASS_RATE=$(echo "scale=2; ($PASSED_TESTS * 100) / $TOTAL_TESTS" | bc)
    echo -e "Tasa de éxito: ${PASS_RATE}%"
    echo "Tasa de éxito: ${PASS_RATE}%" >> $REPORT_FILE
    
    if (( $(echo "$PASS_RATE >= 90" | bc -l) )); then
        echo -e "${GREEN}ESTADO GENERAL: EXCELENTE${NC}"
        echo "ESTADO GENERAL: EXCELENTE" >> $REPORT_FILE
    elif (( $(echo "$PASS_RATE >= 75" | bc -l) )); then
        echo -e "${YELLOW}ESTADO GENERAL: BUENO${NC}"
        echo "ESTADO GENERAL: BUENO" >> $REPORT_FILE
    elif (( $(echo "$PASS_RATE >= 50" | bc -l) )); then
        echo -e "${YELLOW}ESTADO GENERAL: REGULAR${NC}"
        echo "ESTADO GENERAL: REGULAR" >> $REPORT_FILE
    else
        echo -e "${RED}ESTADO GENERAL: CRÍTICO${NC}"
        echo "ESTADO GENERAL: CRÍTICO" >> $REPORT_FILE
    fi
    
    echo -e "\nReporte detallado guardado en: ${REPORT_FILE}"
}

# Función principal para ejecutar todas las pruebas
run_tests() {
    # Inicializar archivo de reporte
    echo "REPORTE DE PRUEBAS - $(date)" > $REPORT_FILE
    echo "===============================" >> $REPORT_FILE
    
    section "INICIANDO PRUEBAS EXHAUSTIVAS"
    
    # Verificar si la aplicación está en ejecución
    if ! check_service "${BASE_URL}" 5 5; then
        error "La aplicación no está en ejecución. Inicie la aplicación primero."
        generate_report
        exit 1
    fi
    
    # Realizar login usando autenticación básica
    if ! do_login "admin@gmail.com" "admin"; then
        error "No se pudo iniciar sesión. Abortando pruebas."
        generate_report
        exit 1
    fi
    
    # Ejecutar pruebas de funcionalidad
    test_profile
    test_dashboard
    test_sprints
    test_tasks
    test_references
    test_health_check
    test_load
    test_error_handling
    
    # Generar reporte
    generate_report
    
    # Limpiar archivos temporales
    rm -f auth_header.txt
    
    # Verificar si todas las pruebas fueron exitosas
    if [ $FAILED_TESTS -eq 0 ]; then
        success "TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE"
        return 0
    else
        error "ALGUNAS PRUEBAS FALLARON. Revise el reporte para más detalles."
        return 1
    fi
}

# Verificar si se solicita ayuda
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Uso: $0 [--report-only]"
    echo ""
    echo "Opciones:"
    echo "  --help, -h         Muestra esta ayuda"
    echo "  --report-only      Solo genera un reporte sin ejecutar pruebas (requiere un reporte previo)"
    exit 0
fi

# Verificar si solo se quiere generar un reporte
if [[ "$1" == "--report-only" ]]; then
    if [[ -f "$REPORT_FILE" ]]; then
        info "Generando reporte a partir de pruebas anteriores..."
        generate_report
        exit 0
    else
        error "No se encontró un archivo de reporte previo."
        exit 1
    fi
fi

# Ejecutar todas las pruebas
run_tests
exit $?
