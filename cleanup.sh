#!/bin/bash

echo "Starting project cleanup..."

# Remove target directory with all build artifacts
echo "Removing build artifacts..."
rm -rf /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final-/target

# Create empty target directory to maintain structure
mkdir -p /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final-/target

# Remove logs directory
echo "Removing logs..."
rm -rf /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final-/logs

# Create empty logs directory to maintain structure
mkdir -p /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final-/logs

# Clean up any temporary files
echo "Removing temporary files..."
find /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final- -name "*.log" -type f -delete
find /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final- -name "*.tmp" -type f -delete
find /root/CODEGYM/aPROYECTO_FINAL/Spring_Camino_4/project-final- -name "*.bak" -type f -delete

echo "Cleanup complete!"
echo ""
echo "=== MAINTAINING A SMALLER PROJECT SIZE ==="
echo "To keep your project size manageable in the future:"
echo "1. Run 'mvn clean' before committing changes"
echo "2. Add these directories to .gitignore:"
echo "   - target/"
echo "   - logs/"
echo "   - pgdata/"
echo "   - pgdata-test/"
echo "3. Avoid committing large binary files"
echo "4. Run this cleanup script periodically"
echo ""
