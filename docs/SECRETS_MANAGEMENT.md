# Gestión de Información Confidencial

## Problema

La aplicación contiene información confidencial directamente en los archivos de configuración:

- Credenciales de base de datos (usuario/contraseña)
- Configuración de correo electrónico (usuario/contraseña)
- Claves de API y secretos para autenticación OAuth2 (GitHub, Google, GitLab)
- Otros datos sensibles

Esto presenta varios problemas de seguridad:

1. **Exposición de secretos en control de versiones**: Los secretos quedan expuestos en el repositorio de código.
2. **Dificultad para gestionar diferentes entornos**: Desarrollo, pruebas y producción requieren diferentes credenciales.
3. **Riesgo de filtración**: Mayor superficie de ataque si alguien obtiene acceso al código fuente.
4. **Incumplimiento de mejores prácticas**: Las auditorías de seguridad penalizan la inclusión de secretos en el código.

## Solución implementada

Hemos implementado una solución basada en variables de entorno y archivos de configuración separados:

### 1. Separación de configuración sensible

- Creado archivo `application-secrets.yaml` para almacenar toda la información confidencial
- Configurado Spring Boot para importar este archivo con `spring.config.import`
- Eliminadas todas las credenciales hardcodeadas del archivo principal `application.yaml`

### 2. Uso de variables de entorno

- Todas las propiedades sensibles ahora se leen de variables de entorno
- Se mantienen valores por defecto para facilitar el desarrollo local
- Formato utilizado: `${NOMBRE_VARIABLE:valorPorDefecto}`

### 3. Gestión de archivos para desarrollo y producción

- Creado `application-secrets.yaml.example` como plantilla con valores por defecto
- El archivo real `application-secrets.yaml` debe añadirse a `.gitignore`
- En entornos de producción, se deben configurar las variables de entorno reales

## Cómo utilizar esta configuración

### Para desarrollo local

1. Copia `application-secrets.yaml.example` a `application-secrets.yaml`
2. Opcionalmente, modifica los valores en `application-secrets.yaml` para tu entorno local
3. La aplicación funcionará con los valores por defecto si no se modifican

### Para entornos de producción

Configura las siguientes variables de entorno en el servidor:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DB_USERNAME` | Usuario de base de datos | jira |
| `DB_PASSWORD` | Contraseña de base de datos | ********** |
| `DB_HOST` | Host de base de datos | localhost |
| `DB_PORT` | Puerto de base de datos | 5432 |
| `DB_NAME` | Nombre de base de datos | jira |
| `MAIL_USERNAME` | Usuario de correo | example@gmail.com |
| `MAIL_PASSWORD` | Contraseña de correo | ********** |
| `MAIL_HOST` | Servidor SMTP | smtp.gmail.com |
| `MAIL_PORT` | Puerto SMTP | 587 |
| `GITHUB_CLIENT_ID` | ID de cliente OAuth2 GitHub | ********** |
| `GITHUB_CLIENT_SECRET` | Secreto de cliente OAuth2 GitHub | ********** |
| `GOOGLE_CLIENT_ID` | ID de cliente OAuth2 Google | ********** |
| `GOOGLE_CLIENT_SECRET` | Secreto de cliente OAuth2 Google | ********** |
| `GITLAB_CLIENT_ID` | ID de cliente OAuth2 GitLab | ********** |
| `GITLAB_CLIENT_SECRET` | Secreto de cliente OAuth2 GitLab | ********** |
| `APP_TEST_MAIL` | Correo para pruebas | test@example.com |

## Ventajas de esta solución

1. **Seguridad mejorada**: Los secretos ya no están en el código fuente
2. **Flexibilidad**: Fácil cambio de configuración entre entornos
3. **Cumplimiento**: Alineado con las mejores prácticas de seguridad
4. **Facilidad de desarrollo**: Mantiene la simplicidad para entornos locales
5. **Compatibilidad con contenedores**: Ideal para despliegues en Docker/Kubernetes

## Consideraciones adicionales

- Asegúrate de que `application-secrets.yaml` esté en `.gitignore`
- Considera el uso de gestores de secretos como HashiCorp Vault o AWS Secrets Manager para entornos empresariales
- Rota periódicamente las credenciales y actualiza las variables de entorno
- Limita el acceso a las variables de entorno en servidores de producción
