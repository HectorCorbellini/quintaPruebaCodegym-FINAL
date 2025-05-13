# Herramientas de Calidad de Código (Optimizadas para Rendimiento)

Este documento describe las herramientas de calidad de código implementadas en el proyecto CodeGym Jira, con especial énfasis en minimizar el impacto en el rendimiento de la aplicación.

## Spring Boot Actuator (Configuración Ligera)

Spring Boot Actuator proporciona características listas para producción para ayudar a monitorear y gestionar la aplicación. Ha sido configurado para minimizar el impacto en el rendimiento.

### Endpoints disponibles (Optimizados)

Se han habilitado solo los endpoints esenciales para minimizar el impacto en el rendimiento:

- `http://localhost:8080/actuator` - Lista de endpoints disponibles
- `http://localhost:8080/actuator/health` - Estado de salud de la aplicación (cacheado por 10 segundos)
- `http://localhost:8080/actuator/info` - Información básica sobre la aplicación
- `http://localhost:8080/actuator/metrics` - Métricas esenciales de la aplicación

Los endpoints que consumen muchos recursos como heapdump y threaddump han sido desactivados.

### Uso

Para acceder a los endpoints de Actuator, la aplicación debe estar en ejecución. Algunos endpoints pueden requerir autenticación.

```bash
# Ejemplo de uso con curl
curl http://localhost:8080/actuator
curl http://localhost:8080/actuator/health
```

## PMD (Análisis Estático de Código Optimizado)

PMD es una herramienta de análisis estático de código que detecta posibles bugs y otros problemas de calidad. Ha sido configurado para minimizar el impacto en el rendimiento durante el desarrollo.

### Ejecución Optimizada

PMD se ejecuta **únicamente** durante la fase de verificación de Maven, no durante la compilación normal, para no ralentizar el desarrollo:

```bash
# Ejecutar solo PMD con configuración optimizada
mvn pmd:check

# Ejecutar como parte del ciclo de vida de Maven (solo en fase verify)
mvn verify
```

**Optimizaciones implementadas:**
- Uso de caché de análisis para evitar re-escanear código no modificado
- Procesamiento multihilo (4 hilos) para análisis más rápido
- Exclusión de archivos de prueba y código generado

### Reglas configuradas (Enfoque en lo esencial)

Para maximizar el rendimiento, se ha limitado el conjunto de reglas a lo más importante:

- **Error Prone**: Solo las reglas que detectan código propenso a errores críticos

El conjunto de reglas "Best Practices" se ha desactivado para mejorar el rendimiento, ya que estas reglas son menos críticas y pueden generar muchas advertencias en código funcional.

### Informes

Los informes de PMD se generan en el directorio `target/site`:

- `target/site/pmd.html` - Informe de problemas detectados por PMD
- `target/site/cpd.html` - Informe de código duplicado

## Integración en el Flujo de Trabajo (Enfoque en Rendimiento)

Para obtener el máximo beneficio sin afectar el rendimiento:

1. Durante el desarrollo normal, **no es necesario** ejecutar PMD constantemente
2. Ejecuta `mvn verify` solo antes de commits importantes o al finalizar funcionalidades
3. Usa los endpoints de Actuator principalmente en entornos de prueba y producción
4. Prioriza la corrección de problemas críticos reportados por PMD

Este enfoque garantiza que las herramientas de calidad no ralenticen el proceso de desarrollo.

## Script de Diagnóstico de Calidad (quality_check.sh)

Se ha creado un script integral para realizar un diagnóstico completo de la calidad del código y rendimiento de la aplicación.

### Características

- **Análisis de código con PMD**: Detecta problemas de calidad y proporciona sugerencias de mejora
- **Métricas de rendimiento**: Analiza el uso de memoria, CPU y número de hilos activos
- **Verificación de salud**: Comprueba el estado de la aplicación y sus componentes
- **Recomendaciones personalizadas**: Genera sugerencias para mejorar código, rendimiento y seguridad
- **Resultados visuales**: Presenta la información con colores para facilitar la interpretación

### Uso

```bash
# Asegúrate de que el script tiene permisos de ejecución
chmod +x quality_check.sh

# Ejecutar el script (la aplicación debe estar en ejecución para algunas funcionalidades)
./quality_check.sh
```

### Requisitos

- Maven (`mvn`)
- cURL (`curl`)
- jq (para procesar JSON, opcional pero recomendado)
- bc (para cálculos, opcional)

### Secciones del Informe

1. **Análisis PMD**: Muestra problemas de calidad de código detectados
2. **Métricas de Actuator**: Presenta estadísticas de uso de recursos
3. **Estado de Salud**: Verifica si la aplicación está funcionando correctamente
4. **Recomendaciones**: Sugiere mejoras en calidad, rendimiento, seguridad y mantenibilidad

## Configuración

- La configuración de Actuator se encuentra en `src/main/resources/actuator.properties`
- La configuración de PMD se encuentra en el archivo `pom.xml`
- El script de diagnóstico está en `quality_check.sh`
