#!/bin/bash

# Script para verificar la calidad del código usando PMD y Spring Boot Actuator
# Autor: Cascade AI
# Fecha: 2025-05-11

# Colores para mejor visualización
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Función para mostrar mensajes informativos
info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

# Función para mostrar mensajes de éxito
success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

# Función para mostrar mensajes de error
error() {
    echo -e "${RED}✗ ${NC}$1"
}

# Función para mostrar mensajes de advertencia
warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

# Función para mostrar títulos de sección
section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

# Función para verificar si un comando existe
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "El comando '$1' no está disponible. Por favor, instálalo."
        return 1
    fi
    return 0
}

# Función para verificar si la aplicación está en ejecución
check_app_running() {
    info "Verificando si la aplicación está en ejecución..."
    
    if curl -s http://localhost:8080/actuator/health &> /dev/null; then
        success "La aplicación está en ejecución."
        return 0
    else
        warning "La aplicación no está en ejecución. No se podrán realizar pruebas con Actuator."
        return 1
    fi
}

# Función para ejecutar análisis PMD
run_pmd_analysis() {
    section "ANÁLISIS PMD"
    
    info "Ejecutando análisis PMD..."
    
    # Crear directorio temporal para informes
    mkdir -p ./target/quality-reports
    
    # Ejecutar PMD y guardar salida en archivo
    mvn pmd:check -Dformat=xml -DoutputDirectory=./target/quality-reports -DtargetJdk=17 > ./target/quality-reports/pmd-output.txt 2>&1
    
    # Verificar resultado
    if [ $? -eq 0 ]; then
        success "No se encontraron problemas con PMD."
        echo ""
        return 0
    else
        error "Se encontraron problemas con PMD."
        
        # Extraer y mostrar los problemas encontrados
        echo -e "\n${BOLD}Problemas encontrados:${NC}\n"
        
        # Buscar líneas con violaciones de PMD en la salida
        grep -A 2 "PMD.* Rule" ./target/quality-reports/pmd-output.txt | while read -r line; do
            if [[ $line == *"PMD"* && $line == *"Rule"* ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "  $line"
            fi
        done
        
        # Sugerencias de mejora
        echo -e "\n${BOLD}${MAGENTA}Sugerencias de mejora:${NC}\n"
        echo -e "1. Revisa las violaciones de reglas PMD y corrige los problemas identificados."
        echo -e "2. Prioriza los problemas en archivos críticos del negocio."
        echo -e "3. Considera añadir comentarios @SuppressWarnings para falsos positivos."
        
        return 1
    fi
}

# Función para verificar métricas con Actuator
check_actuator_metrics() {
    section "MÉTRICAS DE ACTUATOR"
    
    if ! check_app_running; then
        warning "Omitiendo verificación de métricas de Actuator."
        return 1
    fi
    
    info "Obteniendo métricas de la aplicación..."
    
    # Obtener lista de métricas disponibles
    metrics_list=$(curl -s http://localhost:8080/actuator/metrics | jq -r '.names[]')
    
    # Verificar si jq está disponible
    if [ $? -ne 0 ]; then
        error "No se pudo analizar la respuesta JSON. Asegúrate de tener 'jq' instalado."
        return 1
    fi
    
    # Mostrar métricas importantes
    echo -e "${BOLD}Métricas clave:${NC}\n"
    
    # Memoria
    memory_used=$(curl -s "http://localhost:8080/actuator/metrics/jvm.memory.used" | jq -r '.measurements[0].value // "0"')
    memory_max=$(curl -s "http://localhost:8080/actuator/metrics/jvm.memory.max" | jq -r '.measurements[0].value // "1"')
    
    # Verificar si los valores son numéricos
    if [[ "$memory_used" =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ "$memory_max" =~ ^[0-9]+([.][0-9]+)?$ ]] && (( $(echo "$memory_max > 0" | bc -l 2>/dev/null || echo 0) )); then
        memory_percentage=$(echo "scale=2; ($memory_used/$memory_max)*100" | bc -l 2>/dev/null || echo "N/A")
        echo -e "Uso de memoria: ${BOLD}${memory_percentage}%${NC} (${memory_used}/${memory_max} bytes)"
    else
        echo -e "Uso de memoria: ${BOLD}No disponible${NC}"
        memory_percentage="N/A"
    fi
    
    # Verificar uso de memoria
    if [[ "$memory_percentage" != "N/A" ]] && (( $(echo "$memory_percentage > 80" | bc -l 2>/dev/null || echo 0) )); then
        warning "El uso de memoria es alto (>80%). Considera optimizar el consumo de memoria."
    else
        success "El uso de memoria está en un nivel aceptable o no se puede determinar."
    fi
    
    # CPU
    cpu_usage=$(curl -s "http://localhost:8080/actuator/metrics/process.cpu.usage" | jq -r '.measurements[0].value // "0"')
    
    # Verificar si el valor es numérico
    if [[ "$cpu_usage" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        cpu_percentage=$(echo "scale=2; $cpu_usage*100" | bc -l 2>/dev/null || echo "N/A")
        echo -e "Uso de CPU: ${BOLD}${cpu_percentage}%${NC}"
    else
        echo -e "Uso de CPU: ${BOLD}No disponible${NC}"
        cpu_percentage="N/A"
    fi
    
    # Verificar uso de CPU
    if [[ "$cpu_percentage" != "N/A" ]] && (( $(echo "$cpu_percentage > 70" | bc -l 2>/dev/null || echo 0) )); then
        warning "El uso de CPU es alto (>70%). Considera optimizar operaciones intensivas."
    else
        success "El uso de CPU está en un nivel aceptable o no se puede determinar."
    fi
    
    # Hilos
    threads=$(curl -s "http://localhost:8080/actuator/metrics/jvm.threads.live" | jq -r '.measurements[0].value // "N/A"')
    
    if [[ "$threads" =~ ^[0-9]+$ ]]; then
        echo -e "Hilos activos: ${BOLD}${threads}${NC}"
    else
        echo -e "Hilos activos: ${BOLD}No disponible${NC}"
        threads="N/A"
    fi
    
    # Verificar número de hilos
    if [[ "$threads" != "N/A" ]] && (( threads > 100 )); then
        warning "El número de hilos activos es alto (>100). Verifica posibles fugas de recursos."
    else
        success "El número de hilos está en un nivel aceptable o no se puede determinar."
    fi
    
    # HTTP
    http_server_requests=$(curl -s "http://localhost:8080/actuator/metrics/http.server.requests" | jq -r '.availableTags // "[]"')
    
    echo -e "\n${BOLD}Estadísticas de peticiones HTTP:${NC}"
    if [[ "$http_server_requests" != "[]" && "$http_server_requests" != "null" ]]; then
        echo "$http_server_requests" | grep -o '"tag":"status","values":\["[0-9]*"\]' | sed 's/"tag":"status","values":\["\([0-9]*\)"\]/Status \1/g' || echo "  No hay datos disponibles"
    else
        echo "  No hay datos disponibles"
    fi
    
    return 0
}

# Función para verificar la salud de la aplicación
check_health() {
    section "ESTADO DE SALUD"
    
    if ! check_app_running; then
        warning "Omitiendo verificación de salud."
        return 1
    fi
    
    info "Obteniendo estado de salud de la aplicación..."
    
    # Obtener estado de salud
    health_response=$(curl -s http://localhost:8080/actuator/health)
    health_status=$(echo "$health_response" | jq -r '.status // "UNKNOWN"')
    
    if [ "$health_status" == "UP" ]; then
        success "La aplicación está saludable (status: ${BOLD}${health_status}${NC})"
        
        # Obtener componentes de salud si están disponibles
        components=$(echo "$health_response" | jq -r '.components // empty')
        
        if [[ ! -z "$components" && "$components" != "null" ]]; then
            echo -e "\n${BOLD}Componentes:${NC}"
            echo "$components" | jq -r 'keys[]' 2>/dev/null | while read -r component; do
                if [[ ! -z "$component" ]]; then
                    component_status=$(echo "$components" | jq -r ".[\"$component\"].status // \"UNKNOWN\"")
                    
                    if [ "$component_status" == "UP" ]; then
                        echo -e "  ${GREEN}✓${NC} $component: $component_status"
                    else
                        echo -e "  ${RED}✗${NC} $component: $component_status"
                    fi
                fi
            done
        fi
    else
        error "La aplicación no está saludable (status: ${BOLD}${health_status}${NC})"
        
        # Mostrar detalles si están disponibles
        details=$(echo "$health_response" | jq -r '.details // empty')
        
        if [[ ! -z "$details" && "$details" != "null" ]]; then
            echo -e "\n${BOLD}Detalles:${NC}"
            echo "$details" | jq '.' 2>/dev/null || echo "  No se pueden mostrar los detalles"
        fi
    fi
    
    return 0
}

# Función para generar recomendaciones generales
generate_recommendations() {
    section "RECOMENDACIONES GENERALES"
    
    echo -e "${BOLD}${MAGENTA}Basado en el análisis, se recomienda:${NC}\n"
    
    # Recomendaciones de código
    echo -e "${BOLD}1. Calidad de código:${NC}"
    echo -e "   - Resolver las violaciones de PMD, priorizando errores críticos"
    echo -e "   - Revisar clases con alta complejidad ciclomática"
    echo -e "   - Eliminar código muerto y variables no utilizadas"
    
    # Recomendaciones de rendimiento
    echo -e "\n${BOLD}2. Rendimiento:${NC}"
    echo -e "   - Optimizar consultas a base de datos (añadir índices si es necesario)"
    echo -e "   - Revisar el uso de memoria en operaciones con grandes colecciones"
    echo -e "   - Considerar la implementación de caché para operaciones costosas"
    
    # Recomendaciones de seguridad
    echo -e "\n${BOLD}3. Seguridad:${NC}"
    echo -e "   - Verificar la validación de entradas en controladores REST"
    echo -e "   - Asegurar que las contraseñas se almacenan con hash seguro"
    echo -e "   - Revisar permisos y roles en endpoints sensibles"
    
    # Recomendaciones de mantenibilidad
    echo -e "\n${BOLD}4. Mantenibilidad:${NC}"
    echo -e "   - Mejorar la documentación de clases y métodos complejos"
    echo -e "   - Seguir el principio DRY (Don't Repeat Yourself)"
    echo -e "   - Considerar la refactorización de clases con demasiadas responsabilidades"
    
    return 0
}

# Función principal
main() {
    section "DIAGNÓSTICO DE CALIDAD DE CÓDIGO"
    info "Iniciando verificación de calidad del código..."
    
    # Verificar comandos necesarios
    check_command "mvn" || exit 1
    check_command "curl" || exit 1
    check_command "jq" || { warning "El comando 'jq' no está disponible. Algunas funcionalidades serán limitadas."; }
    check_command "bc" || { warning "El comando 'bc' no está disponible. Algunas funcionalidades serán limitadas."; }
    
    # Ejecutar análisis PMD
    run_pmd_analysis
    
    # Verificar métricas con Actuator
    check_actuator_metrics
    
    # Verificar salud de la aplicación
    check_health
    
    # Generar recomendaciones
    generate_recommendations
    
    section "RESUMEN"
    info "Diagnóstico de calidad completado."
    echo -e "Consulta los informes detallados en ${BOLD}./target/quality-reports/${NC}"
    
    return 0
}

# Ejecutar función principal
main "$@"
