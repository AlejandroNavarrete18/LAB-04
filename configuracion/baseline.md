# Línea base de seguridad — PostgreSQL 18 (Windows)

## 1. Red
| Elemento | Valor |
|---|---|
| Interfaces autorizadas | `localhost` (`127.0.0.1` y `::1`) |
| Puerto | 5432/TCP (documentado; no se considera control de seguridad) |
| Redes permitidas | Solo el propio equipo. Si se requiere acceso remoto, un equipo DBA concreto (IP por definir), nunca un rango amplio |

**Política de firewall (Act. 14, conceptual):** el equipo tiene `192.168.1.12` en la LAN, y también adaptadores WSL (`172.24.16.1`) y de red virtual (`192.168.56.1`).
| Origen | Destino | Puerto | Acción |
|---|---|---|---|
| Equipo DBA autorizado (IP por definir) | PostgreSQL `192.168.1.12` | 5432 | Permitir (solo si se justifica) |
| Cualquier otro origen | PostgreSQL | 5432 | Denegar |
En Windows se implementaría con una regla de entrada en el Firewall de Windows con Defender; no se modifica el firewall institucional.

## 2. Autenticación
- Método: `scram-sha-256` en todas las reglas; sin `trust`.
- `password_encryption = scram-sha-256`.
- Credenciales: contraseña única por cuenta, longitud mínima de 14 caracteres, rotación periódica, sin contraseñas en scripts o repositorios.
- Cuentas administrativas: `postgres` (SUPERUSER) y `dba_admin` (CREATEROLE, CREATEDB), solo para administración.

## 3. Autorización
- Roles: `dba_admin`, `app_user`, `consulta_user`; `analista` y `soporte` sin inicio de sesión.
- Privilegios: aplicación con lo mínimo necesario; consulta solo lectura.
- Cuentas de aplicación: nunca SUPERUSER ni CREATEROLE.

| Cuenta | Propósito | LOGIN | Privilegios |
|---|---|---|---|
| DBA (`dba_admin`) | Administración | Sí | Administrativos (sin SUPERUSER) |
| APP (`app_user`) | Aplicación | Sí | Mínimos |
| CONSULTA (`consulta_user`) | Consulta | Sí | Solo lectura |

## 4. Configuración
| Parámetro | Valor objetivo |
|---|---|
| listen_addresses | `localhost` |
| ssl / ssl_min_protocol_version | `on` / `TLSv1.2` |
| log_connections / log_disconnections | activados |
| idle_in_transaction_session_timeout | `60s` |
| statement_timeout | por rol |
| superuser_reserved_connections | `3` |
| max_connections | `100` (revisar con la demanda real) |
- Extensiones: `plpgsql` (necesaria) y `pgcrypto` (práctica de LAB-02; mantener solo si se usa).

## 5. Sistema operativo
- Cuenta de servicio: `NETWORK SERVICE` (confirmar en `services.msc`).
- Permisos objetivo: solo cuenta de servicio, `SYSTEM` y Administradores sobre el directorio de datos y los archivos de configuración; sin el usuario personal ni el grupo `Users`.
- Llaves privadas de TLS accesibles únicamente por la cuenta de servicio.

## 6. Cifrado
- TLS ≥ 1.2 en servidor y clientes; `hostssl` en las reglas de acceso de red.
- Credenciales con SCRAM; contraseñas fuera del código.
- Información sensible: protegida según LAB-01 y LAB-02.

## 7. Mantenimiento
- Actualización: aplicar versiones menores de PostgreSQL 18 al menos trimestralmente (y de inmediato las correcciones de seguridad), primero en un entorno de pruebas.
- Revisión periódica (trimestral): `pg_hba.conf`, roles, extensiones, permisos de archivos, firewall, TLS y logs.
- Documentación: cambios registrados en `cambios.md` con fecha y responsable; línea base versionada en git.