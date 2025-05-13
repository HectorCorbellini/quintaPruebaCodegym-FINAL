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
