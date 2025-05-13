#!/bin/bash

# Limpiar cualquier contenedor existente
echo "Limpiando contenedores existentes..."
docker rm -f postgres-db postgres-db-test || true

# Matar procesos que usan los puertos 5432 y 5433
echo "Matando procesos que usan los puertos 5432 y 5433..."
PID_5432=$(lsof -t -i:5432)
if [ ! -z "$PID_5432" ]; then
    echo "Matando proceso $PID_5432 que está usando el puerto 5432..."
    kill -9 $PID_5432 || true
    sleep 2
fi

PID_5433=$(lsof -t -i:5433)
if [ ! -z "$PID_5433" ]; then
    echo "Matando proceso $PID_5433 que está usando el puerto 5433..."
    kill -9 $PID_5433 || true
    sleep 2
fi

# Iniciar la base de datos de producción
echo "Iniciando la base de datos de producción..."
docker run --name postgres-db \
    -e POSTGRES_USER=jira \
    -e POSTGRES_PASSWORD=CodeGymJira \
    -e POSTGRES_DB=jira \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    -v $(pwd)/pgdata:/var/lib/postgresql/data \
    --network host \
    -d \
    postgres:13

# Esperar a que la base de datos de producción esté lista
echo "Esperando a que la base de datos de producción esté lista..."
sleep 5

# Verificar que la base de datos de producción está funcionando
echo "Verificando la conexión a la base de datos de producción..."
docker exec postgres-db pg_isready -U jira
if [ $? -ne 0 ]; then
    echo "La base de datos de producción no está lista. Esperando 10 segundos más..."
    sleep 10
    docker exec postgres-db pg_isready -U jira
    if [ $? -ne 0 ]; then
        echo "Error: No se pudo conectar a la base de datos de producción. Saliendo."
        exit 1
    fi
fi

# Compile the application with detailed warnings
echo "Compiling the application with detailed warnings..."
mvn clean install -DskipTests -Dpmd.skip=true -Dmaven.compiler.showWarnings=true -Dmaven.compiler.showDeprecation=true

# Check if compilation was successful
if [ $? -ne 0 ]; then
    echo "Compilation failed. Exiting."
    exit 1
fi

# Inform about warnings (they are not errors)
echo "Note: Warnings about unchecked operations are not critical errors."
echo "      They are just suggestions to improve type safety in the code."
echo "      The application should still run correctly."

# Check if dev_mode parameter was passed
if [ "$1" = "dev_mode" ]; then
    echo "Ejecutando en modo desarrollo automáticamente..."
    
    # Modificar el archivo application-dev.yaml para usar el puerto 5432 en lugar de 5433
    echo "Configurando el entorno de desarrollo para usar la base de datos existente..."
    
    # Crear una copia de seguridad del archivo original
    cp src/main/resources/application-dev.yaml src/main/resources/application-dev.yaml.bak
    
    # Modificar el archivo para usar el puerto 5432 y la base de datos jira
    sed -i 's/jdbc:postgresql:\/\/localhost:5433\/jira-test/jdbc:postgresql:\/\/localhost:5432\/jira/' src/main/resources/application-dev.yaml
    
    # Ejecutar la aplicación en modo desarrollo
    mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=dev"
    exit 0
fi

# Ask user to choose between production and development modes
echo ""
echo "Seleccione el modo de ejecución:"
echo "1) Modo producción"
echo "2) Modo desarrollo (por defecto)"
echo ""
read -p "Ingrese su opción (1 o 2): " mode_option

# Set default if no input is provided
if [ -z "$mode_option" ]; then
    mode_option=2
fi

# Run the application based on the selected mode
case $mode_option in
    1)
        echo "Ejecutando en modo producción..."
        # Usar el contenedor de producción existente
        mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=prod"
        ;;
    2)
        echo "Ejecutando en modo desarrollo..."
        
        # Modificar el archivo application-dev.yaml para usar el puerto 5432 en lugar de 5433
        echo "Configurando el entorno de desarrollo para usar la base de datos existente..."
        
        # Crear una copia de seguridad del archivo original
        cp src/main/resources/application-dev.yaml src/main/resources/application-dev.yaml.bak
        
        # Modificar el archivo para usar el puerto 5432 y la base de datos jira
        sed -i 's/jdbc:postgresql:\/\/localhost:5433\/jira-test/jdbc:postgresql:\/\/localhost:5432\/jira/' src/main/resources/application-dev.yaml
        
        # Ejecutar la aplicación en modo desarrollo
        mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=dev"
        
        # Restaurar el archivo original
        mv src/main/resources/application-dev.yaml.bak src/main/resources/application-dev.yaml
        ;;
    *)
        echo "Opción no válida. Ejecutando en modo desarrollo (por defecto)..."
        
        # Modificar el archivo application-dev.yaml para usar el puerto 5432 en lugar de 5433
        echo "Configurando el entorno de desarrollo para usar la base de datos existente..."
        
        # Crear una copia de seguridad del archivo original
        cp src/main/resources/application-dev.yaml src/main/resources/application-dev.yaml.bak
        
        # Modificar el archivo para usar el puerto 5432 y la base de datos jira
        sed -i 's/jdbc:postgresql:\/\/localhost:5433\/jira-test/jdbc:postgresql:\/\/localhost:5432\/jira/' src/main/resources/application-dev.yaml
        
        # Ejecutar la aplicación en modo desarrollo
        mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=dev"
        
        # Restaurar el archivo original
        mv src/main/resources/application-dev.yaml.bak src/main/resources/application-dev.yaml
        ;;
esac
