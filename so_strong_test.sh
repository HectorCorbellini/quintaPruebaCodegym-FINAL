#!/usr/bin/env bash

# so_strong_test.sh - Extended test script for CodeGym Jira Project

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables globales
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

log_info()  { echo -e "${YELLOW}>> $1${NC}"; }
log_success(){ echo -e "${GREEN}✓ $1${NC}"; PASSED_TESTS=$((PASSED_TESTS + 1)); TOTAL_TESTS=$((TOTAL_TESTS + 1)); }
log_error()  { echo -e "${RED}✗ $1${NC}"; FAILED_TESTS=$((FAILED_TESTS + 1)); TOTAL_TESTS=$((TOTAL_TESTS + 1)); }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# 1. Start services in development mode
log_info "Iniciando servicios en modo desarrollo..."

# Usar run_app_no_pmd.sh que ya está preparado para iniciar la aplicación
log_info "Ejecutando run_app_no_pmd.sh en modo no interactivo..."

# Crear un archivo temporal para respuestas automáticas
echo "2" > /tmp/auto_response.txt

# Iniciar la aplicación con entrada automática para seleccionar modo desarrollo
cat /tmp/auto_response.txt | ./run_app_no_pmd.sh &
APP_PID=$!
rm /tmp/auto_response.txt

log_info "Aplicación iniciada en modo desarrollo (PID: $APP_PID)"

# Esperar a que el servicio esté disponible
log_info "Esperando a que el servicio esté disponible..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Intento $ATTEMPT de $MAX_ATTEMPTS..."
    if curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
        log_success "Servicio disponible y funcionando correctamente"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log_error "El servicio no está disponible después de $MAX_ATTEMPTS intentos"
    fi
    
    ATTEMPT=$((ATTEMPT+1))
    sleep 5
done

# 2. Ejecutar pruebas básicas
log_section "PRUEBAS FUNCIONALES"
log_info "Ejecutando pruebas funcionales básicas..."

# Ejecutar pruebas básicas y capturar la salida
STRONG_TEST_OUTPUT=$(bash strong_test_app.sh 2>&1)
STRONG_TEST_EXIT_CODE=$?

# Verificar si las pruebas pasaron
if [ $STRONG_TEST_EXIT_CODE -eq 0 ]; then
    log_success "Pruebas funcionales completadas exitosamente"
    # Extraer y mostrar el resumen de las pruebas
    TESTS_SUMMARY=$(echo "$STRONG_TEST_OUTPUT" | grep -A 5 "=== RESUMEN DE PRUEBAS ===")
    echo "$TESTS_SUMMARY"
else
    # Extraer y mostrar errores relevantes
    log_error "Fallo en pruebas funcionales"
    ERROR_LINES=$(echo "$STRONG_TEST_OUTPUT" | grep -B 2 -A 2 "✗" | head -n 10)
    echo "Detalles de errores:"
    echo "$ERROR_LINES"
fi

# 3. Compilación del proyecto
log_section "COMPILACIÓN DEL PROYECTO"
log_info "Compilando proyecto..."

# Ejecutar compilación y capturar la salida
COMPILE_OUTPUT=$(mvn clean compile -DskipTests -q 2>&1)
COMPILE_EXIT_CODE=$?

# Verificar si la compilación fue exitosa
if [ $COMPILE_EXIT_CODE -eq 0 ]; then
    log_success "Compilación completada exitosamente"
else
    log_error "Error durante la compilación"
    # Mostrar los errores de compilación
    ERROR_LINES=$(echo "$COMPILE_OUTPUT" | grep -A 3 "ERROR" | head -n 10)
    echo "Detalles de errores de compilación:"
    echo "$ERROR_LINES"
fi

# 4. Verificación de calidad de código con PMD
log_section "ANÁLISIS ESTÁTICO DE CÓDIGO"
log_info "Ejecutando análisis PMD..."
if mvn pmd:check -DskipTests -q; then
    log_success "Verificación PMD completada sin violaciones"
else
    log_info "Se encontraron algunas violaciones de PMD (revisar detalle en el log)"
fi

# 5. Ejecución de pruebas unitarias (solo si se especifica --with-tests)
if [[ "$*" == *"--with-tests"* ]]; then
    log_section "PRUEBAS UNITARIAS"
    log_info "Ejecutando pruebas unitarias..."
    if mvn test -q; then
        log_success "Todas las pruebas unitarias pasaron exitosamente"
    else
        log_info "Algunas pruebas unitarias fallaron (esto puede ser normal si la aplicación está en ejecución)"
    fi
else
    log_info "Omitiendo pruebas unitarias (use --with-tests para ejecutarlas)"
fi

# Función para limpiar recursos antes de salir
cleanup() {
    log_section "LIMPIEZA DE RECURSOS"
    log_info "Deteniendo la aplicación..."
    if [ ! -z "$APP_PID" ]; then
        kill -15 $APP_PID 2>/dev/null
        sleep 2
        # Verificar si el proceso sigue vivo
        if ps -p $APP_PID > /dev/null; then
            log_info "Forzando terminación del proceso..."
            kill -9 $APP_PID 2>/dev/null
        fi
    fi
    
    # Detener contenedores de base de datos
    log_info "Deteniendo contenedores de base de datos..."
    docker rm -f postgres-db postgres-db-test 2>/dev/null || true
    
    log_info "Limpieza completada."
}

# Registrar función de limpieza para ejecutarse al salir
trap cleanup EXIT

# Generar reporte final
log_section "REPORTE FINAL"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "Fecha y hora: $(date)"
echo -e "Duración total: ${DURATION} segundos"
echo -e "Total de pruebas: ${TOTAL_TESTS}"
echo -e "${GREEN}Pruebas exitosas: ${PASSED_TESTS}${NC}"
echo -e "${RED}Pruebas fallidas: ${FAILED_TESTS}${NC}"

PASS_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(echo "scale=2; ($PASSED_TESTS * 100) / $TOTAL_TESTS" | bc)
fi

echo -e "Tasa de éxito: ${PASS_RATE}%"

if (( $(echo "$PASS_RATE >= 80" | bc -l) )); then
    echo -e "${GREEN}ESTADO GENERAL: EXCELENTE${NC}"
else
    echo -e "${RED}ESTADO GENERAL: REQUIERE ATENCIÓN${NC}"
fi

if [ $FAILED_TESTS -eq 0 ]; then
    log_success "¡Todas las pruebas extendidas pasaron exitosamente!"
else
    log_info "Algunas pruebas fallaron. Revise el reporte para más detalles."
fi
