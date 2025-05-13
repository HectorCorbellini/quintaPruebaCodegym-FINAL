#!/bin/bash

# Script para probar la funcionalidad de tiempo de tareas
# Este script ejecuta los métodos de cálculo de tiempo de tareas y muestra los resultados

echo "Ejecutando prueba de tiempo de tareas..."

# Verificar si el contenedor de Docker está en ejecución
echo "Verificando si el contenedor de Docker está en ejecución..."
if ! docker ps | grep -q postgres-db; then
    echo "El contenedor postgres-db no está en ejecución. Por favor, ejecuta primero run_app_no_pmd.sh para iniciar la base de datos."
    exit 1
fi

# Crear un archivo SQL temporal con los datos de prueba
echo "Creando archivo SQL temporal..."
cat > /tmp/task_timing_test_temp.sql << 'EOF'
-- Script para insertar registros de prueba para la funcionalidad de tiempo de tareas
-- Este script inserta tres registros en la tabla ACTIVITY para una tarea específica
-- con diferentes estados y timestamps para probar el cálculo de tiempos

-- Asumimos que existe una tarea con ID 1 y un usuario con ID 1
-- Si necesitas usar otros IDs, modifica los valores según corresponda

-- Registro 1: Tarea pasa a estado "in_progress"
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 10:00:00', 'in_progress', 'task', 'Tarea iniciada');

-- Registro 2: Tarea pasa a estado "ready_for_review" después de 2 horas
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 12:00:00', 'ready_for_review', 'task', 'Tarea lista para revisión');

-- Registro 3: Tarea pasa a estado "done" después de 3 horas más
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 15:00:00', 'done', 'task', 'Tarea completada');
EOF

# Ejecutar el script SQL en el contenedor Docker
echo "Insertando datos de prueba en la base de datos..."
docker cp /tmp/task_timing_test_temp.sql postgres-db:/tmp/
docker exec postgres-db psql -U jira -d jira -f /tmp/task_timing_test_temp.sql

# Verificar si los datos se insertaron correctamente
echo "Verificando si los datos se insertaron correctamente..."
docker exec postgres-db psql -U jira -d jira -c "SELECT COUNT(*) FROM ACTIVITY WHERE STATUS_CODE IN ('in_progress', 'ready_for_review', 'done')"

echo "Datos de prueba insertados correctamente."
echo ""
echo "Para probar los métodos implementados, necesitas ejecutar la aplicación con run_app_no_pmd.sh"
echo "y luego usar los siguientes métodos en el servicio ActivityService:"
echo ""
echo "1. calculateDevelopmentTime(1L) - Calcula el tiempo de desarrollo (in_progress -> ready_for_review)"
echo "2. calculateReviewTime(1L) - Calcula el tiempo de revisión (ready_for_review -> done)"
echo ""
echo "Resultados esperados:"
echo "- Tiempo de desarrollo: 120 minutos (2 horas)"
echo "- Tiempo de revisión: 180 minutos (3 horas)"
echo ""
echo "Prueba completada."

# Limpiar archivos temporales
rm /tmp/task_timing_test_temp.sql
