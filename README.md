# LAB-04 — Hardening y configuración segura de PostgreSQL

## Objetivo
Identificar la superficie de ataque de una instancia de PostgreSQL, analizar su configuración actual (red, `pg_hba.conf`, autenticación, roles, TLS, sistema operativo) y proponer medidas de hardening justificadas, con una línea base antes y después.

## Entorno
| Elemento | Valor |
|---|---|
| Motor | PostgreSQL 18.0 (x86_64-windows, msvc-19.44) |
| Sistema operativo | Windows (equipo `DESKTOP-8FI6EE9`) |
| Cliente | VS Code (extensión SQL) y PowerShell |
| Directorio de datos | `C:/Program Files/PostgreSQL/18/data` |
| Interfaces del equipo | `192.168.1.12` (LAN), `172.24.16.1` (WSL), `192.168.56.1` (red virtual), IPv6 global `2806:269:481:876::` |
| Alcance | Entorno académico aislado; los cambios se **proponen y documentan**, no se aplican en un servidor productivo |

## Superficie de ataque inicial
| Elemento | Estado actual | ¿Es necesario? | Riesgo |
|---|---|---|---|
| Puerto PostgreSQL | 5432/TCP, escuchando en `0.0.0.0` y `[::]` (PID 7960) | Sí, pero solo en la interfaz local | Servicio visible en todas las interfaces del equipo |
| Interfaces de escucha | `listen_addresses = *` | No: las conexiones observadas son solo locales (`::1`) | Exposición innecesaria en LAN, WSL, red virtual e IPv6 |
| Conexiones remotas | Ninguna activa; `pg_stat_activity` solo muestra `::1` | No se identificó ninguna necesaria | Superficie sin justificación |
| Usuarios administrativos | `postgres` (SUPERUSER); `dba_admin` (CREATEROLE, CREATEDB) | Sí, solo para administración | Una sesión comprometida con estos roles daría control amplio |
| SSL/TLS | `ssl = on` en el servidor; la sesión actual **no usa TLS** (`ssl = FALSE`) | Sí | TLS disponible pero no exigido |
| Métodos de autenticación | `scram-sha-256` y **`trust`** en `127.0.0.1` y `::1` | Solo `scram-sha-256` | `trust` permite entrar sin contraseña |

## Hallazgos
1. **`pg_hba.conf` con `trust`** en `127.0.0.1` y `::1` para todas las bases y usuarios: cualquier proceso o usuario del equipo puede conectarse, incluso como `postgres`, sin contraseña. Es el hallazgo de mayor riesgo.
2. **Escucha en todas las interfaces** (`*`): el puerto 5432 está abierto en `0.0.0.0` y `[::]`. Hoy `pg_hba.conf` no tiene reglas remotas, por lo que los equipos externos serían rechazados, pero depender solo de `pg_hba.conf` deja una sola capa.
3. **TLS no exigido:** `ssl = on`, pero las reglas usan `host` (no `hostssl`) y la sesión de prueba no usó TLS.
4. **Sin registro de conexiones:** `log_connections` vacío (desactivado) y `log_disconnections = off`.
5. **Sin límites de tiempo:** `statement_timeout = 0` e `idle_in_transaction_session_timeout = 0`.
6. **Archivos de configuración:** `postgresql.conf` y `pg_hba.conf` tienen Control total para el usuario personal `alexd` y `NETWORK SERVICE`, heredado del directorio de datos.
7. **Roles:** hay cuentas separadas (`dba_admin`, `app_user`, `consulta_user`) y roles sin inicio de sesión (`analista`, `soporte`). Solo `postgres` es SUPERUSER. Falta confirmar qué cuenta usa realmente cada aplicación.
8. **Extensiones:** `pgcrypto` (práctica de LAB-02) y `plpgsql` (por defecto).
9. **Positivo:** `password_encryption = scram-sha-256` y ninguna regla abierta a `0.0.0.0/0` ni `::/0`.

## Cambios realizados
Se documentan como **propuesta** (no aplicados) en [`configuracion/cambios.md`](configuracion/cambios.md):
- Cambiar las reglas `trust` por `scram-sha-256` y usar reglas por base de datos, usuario y origen.
- `listen_addresses = 'localhost'` (o localhost más una IP privada si se justifica acceso remoto).
- Exigir TLS (`hostssl`) con versión mínima TLS 1.2.
- Activar `log_connections` y `log_disconnections`.
- Definir `idle_in_transaction_session_timeout` y `statement_timeout` por rol.
- Restringir permisos de archivos de configuración a la cuenta de servicio y Administradores.
- Bloquear 5432 en el Firewall de Windows salvo orígenes autorizados.

## Justificación de los cambios
Cada cambio elimina o limita algo que no es necesario: orígenes que no deben conectarse (red y `pg_hba.conf`), conexiones sin contraseña (`trust`), tráfico sin cifrar (TLS), sesiones sin límite (disponibilidad), acceso a archivos por cuentas que no los necesitan (sistema operativo) y falta de trazabilidad (logs). El puerto no se cambia: modificar 5432 no es un control de seguridad.

## Verificación
Se ejecutó `sql/01-inspeccion.sql`, `02-roles.sql` y `03-configuracion.sql` para el estado inicial. Tras aplicar los cambios, `04-verificacion.sql` y los comandos `netstat -ano | findstr 5432` e `icacls` deben mostrar: escucha solo en loopback, sin reglas `trust`, conexión con TLS ≥ 1.2, registro de conexiones activo y permisos de archivos restringidos.

## Checklist de hardening
Estado según la revisión inicial.
| # | Control | Estado | Evidencia |
|---|---|---|---|
| 1 | Puerto documentado | Cumple | `SHOW port` = 5432; `netstat` |
| 2 | Interfaces de escucha justificadas | No cumple | `listen_addresses = *` |
| 3 | `pg_hba.conf` revisado | Cumple | `pg_hba_file_rules` (6 reglas) |
| 4 | Redes autorizadas restringidas | Parcial | Sin `0.0.0.0/0`; falta firewall |
| 5 | Autenticación segura | No cumple | `trust` en loopback |
| 6 | Superusuarios identificados | Cumple | Solo `postgres` |
| 7 | Cuentas de aplicación separadas | Parcial | `app_user`, `consulta_user` existen; uso por confirmar |
| 8 | Privilegios mínimos | Pendiente | Requiere revisar `role_table_grants` |
| 9 | Extensiones revisadas | Cumple | `pgcrypto`, `plpgsql` |
| 10 | TLS verificado | No cumple | `ssl = on`, sesión sin TLS |
| 11 | Configuración protegida | No cumple | `icacls`: `alexd` y `NETWORK SERVICE` con control total |
| 12 | Directorio de datos protegido | Pendiente | Falta `icacls` del directorio |
| 13 | Firewall documentado | Cumple | `baseline.md` (propuesta) |
| 14 | Actualizaciones documentadas | Cumple | `baseline.md` (Mantenimiento) |
| 15 | Configuración registrada | Cumple | `cambios.md` |
| 16 | Registro de conexiones | No cumple | `log_connections` vacío |
| 17 | Timeouts de sesión | No cumple | Ambos en 0 |

## Conclusiones
La instancia tiene una buena base (SCRAM, sin reglas remotas abiertas, SUPERUSER limitado), pero la combinación de `trust` en loopback, escucha en todas las interfaces y falta de TLS exigido, límites y registro la hace más expuesta de lo necesario. El hardening consiste en reducir lo innecesario y controlar lo que debe permanecer, en varias capas: red, `pg_hba.conf`, autenticación, autorización, sistema operativo y monitoreo.

## Informe

### Preguntas de las actividades
- **Act. 1 — ¿Por qué conocer la superficie de ataque debe preceder al hardening?** No se puede reducir ni proteger lo que no se conoce. Primero se identifica qué está expuesto y qué es necesario; así se decide qué eliminar o restringir y se obtiene un estado inicial para comparar.
- **Act. 2 — ¿Por qué importa conocer la ubicación de los archivos?** Para protegerlos con permisos del sistema operativo, respaldarlos, auditarlos y distinguir datos, configuración, autenticación y logs, que requieren controles distintos.
- **Act. 3 — ¿Qué arquitectura reduce mejor la exposición?** La segunda (servidor en una red privada sin ruta directa desde Internet): reduce los orígenes que pueden alcanzar el puerto 5432 y obliga a pasar por un segmento controlado. En la primera, un error de firewall o de `pg_hba.conf` expone directamente el servicio.
- **Act. 7 — Autenticación vs. autorización:** la primera verifica quién es el usuario; la segunda determina qué puede hacer.
  - *scram-sha-256* protege el intercambio y el almacenamiento de la contraseña (no viaja ni se guarda en claro).
  - Un verificador SCRAM no es cifrado reversible: se almacena un hash con sal, del que no se recupera la contraseña.
  - Con permisos excesivos, una contraseña fuerte no limita el daño: quien se autentique podrá hacer todo lo que permita el rol.
- **Act. 8 — ¿Por qué no usar SUPERUSER para una aplicación?** Un SUPERUSER omite los controles de permisos; si la aplicación se compromete (por ejemplo, inyección SQL), el atacante hereda esa capacidad sobre toda la instancia.
- **Act. 9 — ¿Qué riesgo hay si la aplicación usa una cuenta administrativa?** Un compromiso de la aplicación equivale a comprometer la instancia: borrar datos, crear roles y leer otras bases. Separar DBA, aplicación y consulta limita el alcance.
- **Act. 11 — Parámetros de conexión:** `max_connections` limita las conexiones simultáneas; `superuser_reserved_connections` reserva cupos para superusuarios; `statement_timeout` cancela consultas demasiado largas; `idle_in_transaction_session_timeout` cierra sesiones con transacción abierta e inactiva. *Conexiones indefinidamente abiertas* consumen memoria y cupos, retienen bloqueos y pueden agotar `max_connections`. En este servidor ambos tiempos están en `0` (sin límite).
- **Act. 12 — ¿Por qué no basta GRANT/REVOKE?** Quien lea los archivos desde el sistema operativo puede obtener configuración, reglas de acceso, llaves o datos sin pasar por PostgreSQL.
- **Act. 14 — ¿Por qué `pg_hba.conf` y el firewall no son equivalentes?** El firewall decide si un paquete llega al puerto; `pg_hba.conf` decide qué usuario, base y origen pueden autenticarse y con qué método. Son capas complementarias.

### Act. 18 — Caso integral
| # | Problema | Riesgo | Control propuesto |
|---|---|---|---|
| 1 | Acepta IPv4 desde cualquier dirección | Fuerza bruta y escaneo | Lista de orígenes permitidos en `pg_hba.conf` |
| 2 | `listen_addresses = '*'` | Interfaces innecesarias expuestas | Escuchar solo en localhost/IP privada |
| 3 | Firewall permite 5432 desde cualquier origen | Servicio alcanzable globalmente | Permitir solo orígenes autorizados |
| 4 | `pg_hba.conf` con all/all 0.0.0.0/0 | Cualquier usuario/base desde cualquier lugar | Reglas por base + usuario + origen |
| 5 | Aplicación con usuario administrativo | Un compromiso da control total | Cuenta de aplicación con privilegios mínimos |
| 6 | Privilegios excesivos | Escalada y daño amplio | Mínimo privilegio, sin SUPERUSER |
| 7 | Confiar solo en contraseñas fuertes | Falsa seguridad | Defensa en capas |
| 8 | Sin segmentación de red | Movimiento lateral | Servidor en segmento de BD |
| 9 | TLS no exigido | Intercepción de credenciales y datos | `hostssl`, TLS ≥ 1.2 |
| 10 | Sin registro de conexiones | Accesos sospechosos no detectados | `log_connections`, monitoreo |
| 11 | Sin límites ni timeouts | Agotamiento de conexiones | Timeouts y límites por rol |
| 12 | Archivos de configuración sin revisar | Exposición de configuración y llaves | Permisos restringidos |

**¿Es suficiente tener contraseñas fuertes?** No. La contraseña solo cubre la *autenticación*. Sin *autorización* mínima, un usuario autenticado puede hacer todo lo que permita su rol; sin controles de *red* y `pg_hba.conf`, cualquiera puede intentar conectarse; sin *configuración* segura (TLS, timeouts, `listen_addresses`) y *sistema operativo* protegido, se filtran credenciales o archivos; y sin *monitoreo* no se detectan ataques ni abusos.

### Preguntas del informe
1. **Principal superficie de ataque:** el puerto 5432 escuchando en todas las interfaces (`0.0.0.0` y `[::]`), en un equipo con cuatro adaptadores de red.
2. **Mayor riesgo:** las reglas `trust` en `127.0.0.1` y `::1`: permiten conectarse como cualquier rol, incluso `postgres`, sin contraseña.
3. **Mayor reducción de exposición:** reemplazar `trust` por `scram-sha-256` y limitar `listen_addresses` a `localhost`.
4. **Firewall vs. `pg_hba.conf`:** el firewall filtra el tráfico hacia el puerto; `pg_hba.conf` decide quién puede autenticarse (usuario, base, origen, método).
5. **Autenticación vs. autorización:** identidad verificada vs. privilegios sobre los objetos.
6. **Cuenta de aplicación y SUPERUSER:** un compromiso de la aplicación daría control total de la instancia.
7. **Cambiar el puerto:** solo reduce ruido automatizado; no sustituye autenticación, autorización ni firewall.
8. **`listen_addresses='*'`:** abre interfaces que el servicio no necesita (aquí LAN, WSL, red virtual e IPv6), ampliando la superficie.
9. **Papel del sistema operativo:** protege archivos de configuración, llaves y datos, y controla las cuentas que podrían saltarse la seguridad de PostgreSQL.
10. **Revisión periódica:** `pg_hba.conf`, roles y privilegios, `listen_addresses`, firewall, extensiones, permisos de archivos, TLS, parámetros de conexión, actualizaciones y logs.

### Reflexión
Lo primero que cambiaría en un servidor en producción sería **eliminar el acceso sin contraseña y limitar quién puede alcanzarlo**: reemplazar reglas `trust`/amplias de `pg_hba.conf` por una lista de orígenes permitidos y reducir `listen_addresses`, después de inventariar las conexiones reales con `log_connections` y `pg_stat_activity`.
- **Riesgo y exposición:** es lo que más reduce la probabilidad de un acceso no autorizado.
- **Impacto, disponibilidad y continuidad:** `pg_hba.conf` se recarga sin reiniciar (`pg_reload_conf()`) y, si antes se identifican los clientes legítimos, no se interrumpe el servicio. Cambiar `listen_addresses` exige reinicio y se programa en una ventana.
- **Privilegios y autenticación:** después se separan las cuentas de aplicación de las administrativas y se exige SCRAM, probando primero y conservando un acceso de emergencia local.
- **Red:** va antes que los demás porque limita todo lo que sigue; las contraseñas y los privilegios importan menos si cualquiera puede intentar conectarse.