# Ejecutar desde la terminal en la carpeta proyecto2/
# Sigue exactamente el flujo del documento de entrega


# Copiar pg_hba.conf del nodo1 al pc
docker cp pg_nodo1:/var/lib/postgresql/data/pg_hba.conf ./config/pg_hba.conf

echo "pg_hba.conf copiado a config/pg_hba.conf"
echo "Abre el archivo y añade esta línea al final:"
echo "host replication replicator 0.0.0.0/0 md5"
echo ""
echo "Presiona ENTER cuando hayas guardado el archivo"
read

# Devolver el pg_hba.conf modificado al nodo1
docker cp ./config/pg_hba.conf pg_nodo1:/var/lib/postgresql/data/pg_hba.conf
echo "pg_hba.conf actualizado en pg_nodo1"

# Reiniciar nodo1 para aplicar cambios
docker restart pg_nodo1
echo "pg_nodo1 reiniciado"
echo "Esperando que el nodo arranque..."
sleep 8

# Clonar Primary → Réplica 1 
echo ""
echo "...Configurando pg_replica1..."

docker start pg_replica1

# Limpiar directorio de datos de la réplica
docker exec -it pg_replica1 bash -c "rm -rf /var/lib/postgresql/data/*"

# Ejecutar pg_basebackup (contraseña: replica123)
echo "Contraseña cuando se pida: replica123"
docker exec -it pg_replica1 bash -c \
  "pg_basebackup -h pg_nodo1 -D /var/lib/postgresql/data -U replicator -Fp -Xs -P -R"

# Reiniciar la réplica
docker restart pg_replica1
echo "pg_replica1 configurada y reiniciada"

# Clonar Primary → Réplica 2
echo ""
echo "...Configurando pg_replica2..."

docker start pg_replica2

docker exec -it pg_replica2 bash -c "rm -rf /var/lib/postgresql/data/*"

echo "Contraseña cuando se pida: replica123"
docker exec -it pg_replica2 bash -c \
  "pg_basebackup -h pg_nodo1 -D /var/lib/postgresql/data -U replicator -Fp -Xs -P -R"

docker restart pg_replica2
echo "pg_replica2 configurada y reiniciada"

# Verificación
echo ""
echo "...Verificación..."
echo "Comprobando estado de los contenedores:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "pg_replica|pg_nodo1"