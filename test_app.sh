#!/bin/bash

# Colores para mejor legibilidad
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes de éxito
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Función para imprimir mensajes de error
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Función para imprimir mensajes informativos
info() {
    echo -e "${YELLOW}ℹ $1${NC}"
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
    auth_header="Authorization: Basic $(echo -n "$username:$password" | base64)"
    
    # Verificar si podemos acceder a una API protegida usando autenticación básica
    api_response=$(curl -s -H "$auth_header" "http://localhost:8080/api/profile")
    
    # Verificar si la respuesta indica que estamos autenticados
    if [[ $api_response == *"id"* || $api_response == *"mailNotifications"* || $api_response == *"contacts"* ]]; then
        success "Login exitoso con $username usando autenticación básica"
        # Guardar el header de autenticación para usarlo en las siguientes peticiones
        echo "$auth_header" > auth_header.txt
        return 0
    else
        # Intentar con otro endpoint
        projects_response=$(curl -s -H "$auth_header" "http://localhost:8080/api/projects")
        if [[ $projects_response == *"id"* || $projects_response == *"title"* || $projects_response == *"code"* ]]; then
            success "Login exitoso con $username usando autenticación básica (verificado con proyectos)"
            # Guardar el header de autenticación para usarlo en las siguientes peticiones
            echo "$auth_header" > auth_header.txt
            return 0
        else
            error "Login fallido con $username usando autenticación básica"
            return 1
        fi
    fi
}

# Función para probar la funcionalidad de perfil
test_profile() {
    info "Probando funcionalidad de perfil..."
    
    # Leer el header de autenticación guardado
    auth_header=$(cat auth_header.txt)
    
    # Obtener perfil usando la API con autenticación básica
    response=$(curl -s -H "$auth_header" "http://localhost:8080/api/profile")
    
    if [[ $response == *"id"* || $response == *"mailNotifications"* || $response == *"contacts"* ]]; then
        success "Acceso a perfil exitoso vía API"
        return 0
    else
        error "No se pudo acceder al perfil vía API"
        return 1
    fi
}

# Función para probar la funcionalidad del dashboard
test_dashboard() {
    info "Probando funcionalidad de dashboard..."
    
    # Leer el header de autenticación guardado
    auth_header=$(cat auth_header.txt)
    
    # Obtener proyectos usando la API con autenticación básica
    response=$(curl -s -H "$auth_header" "http://localhost:8080/api/projects")
    
    if [[ $response == *"id"* || $response == *"title"* || $response == *"code"* ]]; then
        success "Acceso a proyectos exitoso vía API"
        return 0
    else
        error "No se pudo acceder a proyectos vía API"
        return 1
    fi
}

# Función para probar la API REST
test_api() {
    info "Probando API REST..."
    
    # Leer el header de autenticación guardado
    auth_header=$(cat auth_header.txt)
    
    # Probar diferentes endpoints de la API
    tasks_response=$(curl -s -H "$auth_header" "http://localhost:8080/api/tasks/by-project?projectId=1")
    
    if [[ $tasks_response == *"id"* || $tasks_response == *"title"* || $tasks_response == *"[]"* ]]; then
        success "API de tareas funcionando correctamente"
        return 0
    else
        # Intentar con un endpoint alternativo
        refs_response=$(curl -s -H "$auth_header" "http://localhost:8080/api/admin/refs/TASK_STATUS")
        if [[ $refs_response == *"id"* || $refs_response == *"code"* || $refs_response == *"[]"* ]]; then
            success "API de referencias funcionando correctamente"
            return 0
        else
            error "No se pudo acceder a los endpoints de la API"
            return 1
        fi
    fi
}

# Función principal para ejecutar todas las pruebas
run_tests() {
    info "Iniciando pruebas de funcionalidad..."
    
    # Verificar si la aplicación está en ejecución
    if ! check_service "http://localhost:8080" 5 5; then
        error "La aplicación no está en ejecución. Inicie la aplicación primero."
        exit 1
    fi
    
    # Realizar login usando autenticación básica
    if ! do_login "admin@gmail.com" "admin"; then
        error "No se pudo iniciar sesión. Abortando pruebas."
        exit 1
    fi
    
    # Ejecutar pruebas de funcionalidad
    test_profile
    profile_result=$?
    
    test_dashboard
    dashboard_result=$?
    
    test_api
    api_result=$?
    
    # Mostrar resumen de resultados
    echo ""
    echo "=== RESUMEN DE PRUEBAS ==="
    if [ $profile_result -eq 0 ]; then
        success "Prueba de perfil: EXITOSA"
    else
        error "Prueba de perfil: FALLIDA"
    fi
    
    if [ $dashboard_result -eq 0 ]; then
        success "Prueba de dashboard: EXITOSA"
    else
        error "Prueba de dashboard: FALLIDA"
    fi
    
    if [ $api_result -eq 0 ]; then
        success "Prueba de API: EXITOSA"
    else
        error "Prueba de API: FALLIDA"
    fi
    
    # Limpiar archivos temporales
    rm -f cookies.txt auth_header.txt
    
    # Verificar si todas las pruebas fueron exitosas
    if [ $profile_result -eq 0 ] && [ $dashboard_result -eq 0 ] && [ $api_result -eq 0 ]; then
        success "TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE"
        return 0
    else
        error "ALGUNAS PRUEBAS FALLARON"
        return 1
    fi
}

# Verificar si se solicita ayuda
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Uso: $0 [--run-app]"
    echo ""
    echo "Opciones:"
    echo "  --run-app    Ejecuta la aplicación antes de realizar las pruebas"
    echo "  --help, -h   Muestra esta ayuda"
    exit 0
fi

# Verificar si se debe ejecutar la aplicación
if [[ "$1" == "--run-app" ]]; then
    info "Ejecutando la aplicación en modo desarrollo..."
    
    # Verificar si la aplicación ya está en ejecución
    if check_service "http://localhost:8080" 1 1; then
        info "La aplicación ya está en ejecución. Continuando con las pruebas..."
    else
        # Ejecutar la aplicación directamente con run_app_dev.sh
        # Este script ya se encarga de configurar la base de datos
        info "Iniciando la aplicación con run_app_dev.sh..."
        ./run_app_dev.sh &
        APP_PID=$!
        
        # Esperar a que la aplicación esté lista
        info "Esperando a que la aplicación esté lista (60 segundos)..."
        sleep 60
    fi
    
    # Ejecutar pruebas
    run_tests
    TEST_RESULT=$?
    
    # Detener la aplicación
    info "Deteniendo la aplicación..."
    kill $APP_PID
    
    exit $TEST_RESULT
else
    # Solo ejecutar pruebas
    run_tests
    exit $?
fi
