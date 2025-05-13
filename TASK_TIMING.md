# Funcionalidad de Seguimiento de Tiempo de Tareas

## Descripción General

Esta funcionalidad permite rastrear y calcular el tiempo que una tarea pasa en diferentes estados durante su ciclo de vida, específicamente:

1. El tiempo que una tarea estuvo en estado "in_progress" hasta pasar a "ready_for_review"
2. El tiempo que una tarea estuvo en estado "ready_for_review" hasta pasar a "done"

Estos cálculos proporcionan métricas valiosas para el análisis de rendimiento del equipo, la planificación de proyectos y la identificación de cuellos de botella en el proceso de desarrollo.

## Implementación Técnica

### Métodos Implementados

Se han añadido dos nuevos métodos al servicio `ActivityService`:

#### 1. `calculateDevelopmentTime(long taskId)`

```java
/**
 * Calcula el tiempo que una tarea estuvo en estado "in_progress" hasta "ready_for_review".
 * 
 * @param taskId ID de la tarea
 * @return Duración en minutos, o null si no se puede calcular
 */
@Transactional(readOnly = true)
public Long calculateDevelopmentTime(long taskId) {
    List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(taskId);
    
    // Ordenamos las actividades de más antiguas a más recientes para procesarlas cronológicamente
    activities.sort((a1, a2) -> a1.getUpdated().compareTo(a2.getUpdated()));
    
    LocalDateTime inProgressTime = null;
    LocalDateTime readyForReviewTime = null;
    
    for (Activity activity : activities) {
        if (activity.getStatusCode() != null) {
            if ("in_progress".equals(activity.getStatusCode()) && inProgressTime == null) {
                inProgressTime = activity.getUpdated();
            } else if ("ready_for_review".equals(activity.getStatusCode()) && inProgressTime != null) {
                readyForReviewTime = activity.getUpdated();
                break; // Encontramos la primera transición de in_progress a ready_for_review
            }
        }
    }
    
    if (inProgressTime != null && readyForReviewTime != null) {
        return Duration.between(inProgressTime, readyForReviewTime).toMinutes();
    }
    
    return null; // No se encontró una transición completa
}
```

#### 2. `calculateReviewTime(long taskId)`

```java
/**
 * Calcula el tiempo que una tarea estuvo en estado "ready_for_review" hasta "done".
 * 
 * @param taskId ID de la tarea
 * @return Duración en minutos, o null si no se puede calcular
 */
@Transactional(readOnly = true)
public Long calculateReviewTime(long taskId) {
    List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(taskId);
    
    // Ordenamos las actividades de más antiguas a más recientes para procesarlas cronológicamente
    activities.sort((a1, a2) -> a1.getUpdated().compareTo(a2.getUpdated()));
    
    LocalDateTime readyForReviewTime = null;
    LocalDateTime doneTime = null;
    
    for (Activity activity : activities) {
        if (activity.getStatusCode() != null) {
            if ("ready_for_review".equals(activity.getStatusCode()) && readyForReviewTime == null) {
                readyForReviewTime = activity.getUpdated();
            } else if ("done".equals(activity.getStatusCode()) && readyForReviewTime != null) {
                doneTime = activity.getUpdated();
                break; // Encontramos la primera transición de ready_for_review a done
            }
        }
    }
    
    if (readyForReviewTime != null && doneTime != null) {
        return Duration.between(readyForReviewTime, doneTime).toMinutes();
    }
    
    return null; // No se encontró una transición completa
}
```

### Lógica de Implementación

1. **Recuperación de Actividades**: Se obtienen todas las actividades asociadas a una tarea específica.
2. **Ordenamiento Cronológico**: Las actividades se ordenan de más antiguas a más recientes para procesarlas en orden temporal.
3. **Identificación de Transiciones**: Se identifican las transiciones entre estados (por ejemplo, de "in_progress" a "ready_for_review").
4. **Cálculo de Duración**: Se calcula la duración entre las transiciones utilizando la API de tiempo de Java 8 (`Duration.between()`).
5. **Manejo de Casos Especiales**: Si no se encuentra una transición completa, el método devuelve `null`.

## Datos de Prueba

Para probar esta funcionalidad, se han creado registros de prueba en la tabla `ACTIVITY` que simulan una tarea que pasa por diferentes estados:

```sql
-- Registro 1: Tarea pasa a estado "in_progress"
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 10:00:00', 'in_progress', 'task', 'Tarea iniciada');

-- Registro 2: Tarea pasa a estado "ready_for_review" después de 2 horas
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 12:00:00', 'ready_for_review', 'task', 'Tarea lista para revisión');

-- Registro 3: Tarea pasa a estado "done" después de 3 horas más
INSERT INTO ACTIVITY (TASK_ID, AUTHOR_ID, UPDATED, STATUS_CODE, TYPE_CODE, TITLE)
VALUES (1, 1, '2025-05-10 15:00:00', 'done', 'task', 'Tarea completada');
```

## Resultados Esperados

Con los datos de prueba proporcionados, los resultados esperados son:

- **Tiempo de Desarrollo** (in_progress → ready_for_review): 120 minutos (2 horas)
- **Tiempo de Revisión** (ready_for_review → done): 180 minutos (3 horas)

## Beneficios

1. **Métricas de Rendimiento**: Permite medir el tiempo real que toma completar diferentes fases del desarrollo.
2. **Identificación de Cuellos de Botella**: Ayuda a identificar qué fases del proceso de desarrollo toman más tiempo.
3. **Planificación de Proyectos**: Proporciona datos históricos para estimar mejor la duración de tareas futuras.
4. **Mejora Continua**: Facilita la identificación de áreas de mejora en el proceso de desarrollo.

## Posibles Mejoras Futuras

1. **Exposición vía API REST**: Crear endpoints REST para acceder a estas métricas desde aplicaciones cliente.
2. **Visualización de Datos**: Implementar gráficos y dashboards para visualizar estas métricas.
3. **Alertas y Notificaciones**: Configurar alertas cuando una tarea permanece demasiado tiempo en un estado.
4. **Análisis Estadístico**: Implementar análisis estadístico para identificar tendencias y patrones.

## Cómo Probar la Funcionalidad

1. Ejecutar la aplicación con el script `run_app_no_pmd.sh` en modo desarrollo.
2. Ejecutar el script `test_task_timing.sh` para insertar los datos de prueba.
3. Utilizar los métodos `calculateDevelopmentTime(1L)` y `calculateReviewTime(1L)` del servicio `ActivityService` para verificar los resultados.
