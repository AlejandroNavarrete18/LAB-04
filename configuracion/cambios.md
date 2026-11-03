# Cambios (propuestos) — LAB-04

> Los cambios se documentan con su justificación. Aplicarlos solo en el entorno académico aislado y, para parámetros que requieren reinicio, reiniciar el servicio de PostgreSQL desde `services.msc`.

## Act. 5 — Regla permisiva (análisis, sin modificarla)
- **Regla conceptual:** `host all all 0.0.0.0/0 scram-sha-256`
- **Bases:** todas. **Usuarios:** todos. **Origen:** cualquier IPv4. **Método:** `scram-sha-256`.
- **Problema:** SCRAM protege la contraseña, pero no limita quién puede intentar conectarse; expone todas las cuentas a fuerza bruta desde cualquier lugar.
- **Información necesaria para restringirla:** qué clientes se conectan realmente (`pg_stat_activity`, logs de conexiones), sus IPs, bases y cuentas que usan.
- **Origen que realmente necesita acceso:** el propio equipo (`127.0.0.1`, `::1`); no se observó ningún cliente remoto.
- **Regla real más riesgosa encontrada:** `host all all 127.0.0.1 trust` y `host all all ::1 trust` (sin contraseña).

## Act. 6 — Reglas propuestas (`pg_hba.conf`)
Base + usuario + origen + método. Nombre de la base de ejemplo: `basedatos_app` (ajustar a la base real).
```
# TYPE    DATABASE        USER            ADDRESS         METHOD
host      basedatos_app   app_user        127.0.0.1/32    scram-sha-256
host      basedatos_app   app_user        ::1/128         scram-sha-256
host      basedatos_app   consulta_user   127.0.0.1/32    scram-sha-256
host      basedatos_app   consulta_user   ::1/128         scram-sha-256
host      all             dba_admin       127.0.0.1/32    scram-sha-256
host      all             dba_admin       ::1/128         scram-sha-256
host      all             postgres        127.0.0.1/32    scram-sha-256
host      all             postgres        ::1/128         scram-sha-256
host      replication     all             127.0.0.1/32    scram-sha-256   # ya existía
host      replication     all             ::1/128         scram-sha-256   # ya existía
```
Si se exige TLS en conexiones de red, cambiar `host` por `hostssl`. Recargar con `SELECT pg_reload_conf();` y revisar `pg_hba_file_rules` (columna `error`).

## Otros cambios propuestos
| Act. | Parámetro / elemento | De | A | Reinicio |
|---|---|---|---|---|
| 3 | `listen_addresses` | `*` | `localhost` | Sí |
| 7 | `password_encryption` | `scram-sha-256` | Sin cambio | — |
| 11 | `log_connections` | vacío | `'receipt,authentication,authorization'` (PostgreSQL 18) | No (reload) |
| 11 | `log_disconnections` | `off` | `on` | No |
| 11 | `idle_in_transaction_session_timeout` | `0` | `60s` | No |
| 11 | `statement_timeout` | `0` | por rol (p. ej. `30s` para `app_user`) | No |
| 15 | `ssl_min_protocol_version` | por registrar | `TLSv1.2` | No |
| 15 | Reglas de acceso remoto | `host` | `hostssl` | No |

## Act. 12 — Permisos del sistema operativo
Resultado de `icacls` (heredado del directorio de datos):
| Archivo | Cuentas con control total |
|---|---|
| `postgresql.conf` | `BUILTIN\Administradores`, `NT AUTHORITY\SYSTEM`, `DESKTOP-8FI6EE9\alexd`, `NT AUTHORITY\NETWORK SERVICE` |
| `pg_hba.conf` | Las mismas cuatro |

No aparece el grupo `Users`, lo cual es correcto. Propuesta: quitar el control total del usuario personal (`alexd`) y dejar solo la cuenta de servicio y Administradores, por ejemplo:
```powershell
icacls "C:\Program Files\PostgreSQL\18\data" /inheritance:r
icacls "C:\Program Files\PostgreSQL\18\data" /grant "NT AUTHORITY\NETWORK SERVICE:(OI)(CI)F" "BUILTIN\Administradores:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F"
```
Confirmar antes qué cuenta ejecuta el servicio (`services.msc`) para no impedir el arranque.

## Act. 13 — Exposición de red
```
TCP    0.0.0.0:5432    0.0.0.0:0    LISTENING    7960
TCP    [::]:5432       [::]:0       LISTENING    7960
```
| | Estado actual | Propuesto |
|---|---|---|
| Dirección de escucha | `0.0.0.0` y `[::]` | `127.0.0.1` y `[::1]` |
| Puerto | 5432 | 5432 |
| ¿Expuesto fuera de la interfaz necesaria? | Sí | No |

## Act. 16 — Línea base: antes y después
| Control | Antes | Después (propuesto) | Justificación |
|---|---|---|---|
| `listen_addresses` | `*` | `localhost` | Solo se necesitan conexiones locales |
| `pg_hba.conf` | `trust` en loopback; replicación con SCRAM | Reglas por base, usuario y origen con `scram-sha-256` | Eliminar acceso sin contraseña |
| Método de autenticación | `scram-sha-256` y `trust` | Solo `scram-sha-256` | Autenticar siempre |
| Usuarios administrativos | `postgres`; `dba_admin` | Solo para administración, nunca en aplicaciones | Mínimo privilegio |
| Cuentas de aplicación | `app_user`, `consulta_user` | Confirmar que las aplicaciones usen estas cuentas | Limitar el impacto de un compromiso |
| Puerto | 5432 | 5432 | Cambiarlo no es hardening |
| TLS | `ssl = on`, sesión sin TLS | `hostssl`, TLS ≥ 1.2 | Cifrar credenciales y datos |
| Permisos SO | Control total de `alexd` y `NETWORK SERVICE` | Solo cuenta de servicio y Administradores | Proteger archivos sensibles |
| Extensiones | `pgcrypto`, `plpgsql` | Mantener; `pgcrypto` solo si se usa | Funcionalidad mínima |
| Conexiones | Sin registro ni timeouts | Registro activo y timeouts | Trazabilidad y disponibilidad |