# Laboratorio de Optimización de Base de Datos - EAFIT 2026-1

Este repositorio contiene la solución al laboratorio de optimización de Bases de Datos. Se incluye un dataset de gran volumen y una serie de consultas diseñadas para analizar cuellos de botella y aplicar estrategias de indexación.

## 1. Requisitos de Infraestructura
* Instancia EC2 en AWS Academy (Ubuntu 24.04).
* Tipo: **t2.large** (mínimo) con **40 GB** de disco duro.
* Docker y Docker Compose instalados.

## 2. Despliegue Rápido
1. Clonar el repositorio:
   ```bash
   git clone <https://github.com/sherrerah3/BD-Avanzadas>
   cd pg-lab1

**Lanzar los servicios** (Postgres se inicializará automáticamente con el esquema y datos pesados):
```docker compose up -d```

**Túnel SSH:** Desde tu pc, abre un túnel para acceder a pgAdmin:
```ssh -i "tu-llave.pem" ubuntu@<ip-publica> -L 5050:localhost:5050```

**Conexión pgAdmin:**    
* URL: http://localhost:5050
* Usuario: user@acme.com | Clave: adminpass
* Host de BD: Usa la IP privada de la EC2 o el nombre del servicio postgres.
* Credenciales: labuser / labpass / DB: labdb.


### Contenido y solucion
**Informes y Grafico con Resultados:** [Enlace al Drive](https://drive.google.com/drive/folders/1Jf7MZCBJH5lqnBI_LQ8zhN7ri3XgRnGT?usp=sharing)

<img width="320" height="232" alt="image" src="https://github.com/user-attachments/assets/7a6eec23-d6ef-4fac-b200-c89fb122cf3d" />


**Análisis de Rendimiento:** En `scripts/queries.sql` se encuentran las consultas base (Q1 a Q8) para ejecutar con `EXPLAIN (ANALYZE, BUFFERS)`.

**Optimización:** En `scripts/optimizations.sql` se proponen índices, particiones, reescritura, segun sea necesario, para reducir los tiempos de respuesta.

