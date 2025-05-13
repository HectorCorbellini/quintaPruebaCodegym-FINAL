#!/bin/bash

# Ejecutar run_app.sh con el argumento dev_mode para indicar modo desarrollo
if [ -f "./run_app.sh" ]; then
    # Llamar al script principal con un argumento especial
    ./run_app.sh dev_mode
else
    echo "Error: No se encuentra el archivo run_app.sh"
    exit 1
fi
