
# BAS Prüfungsgenerator - Hosting & Deployment

Dieses Projekt stellt ein Docker-Image bereit, das Frontend und Backend des BAS Prüfungsgenerators enthält. Das Image wird automatisch unter `ghcr.io/campus-12/bas-pruefungsgenerator-container:latest` veröffentlicht (siehe GitHub Actions Workflow `.github/workflows/docker-publish.yml`).

## Voraussetzungen

- Docker und Docker Compose müssen installiert sein
- Zugang zur GitHub Container Registry (ghcr.io)

### Login in die GitHub Container Registry

Da das Image in der GitHub Container Registry (ghcr.io) gehostet wird, müssen Sie sich authentifizieren:

```bash
# Login mit GitHub Token (empfohlen)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Oder interaktiver Login
docker login ghcr.io
```

**Meetle: GitHub Token erstellen:**

1. Gehen Sie zu GitHub Settings > Developer settings > Personal access tokens
2. Erstellen Sie ein Token mit `read:packages` Berechtigung
3. Verwenden Sie dieses Token als Passwort beim Login

## Schnellstart mit Docker Compose

Erstellen Sie im Projekt-Root eine Datei `docker-compose.yml` mit folgendem Inhalt. Die Anwendung nutzt das veröffentlichte Image und verbindet sich mit einer externen PostgreSQL-Datenbank.

```yaml
version: '3.8'

services:
	app:
		image: ghcr.io/campus-12/bas-pruefungsgenerator-container:latest
		ports:
			- "80:80"
		volumes:
			- ${APP_DATA_PATH:-app_data}:/data
		depends_on:
			- db
		environment:
			# Backend Environment Variables (Required)
			- CONSOLE_LOG_LEVEL=*
			- DB_CONNECTION=postgres://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@db:5432/${POSTGRES_DB:-postgres}?sslmode=disable
			# LDAP Configuration (Required)
			- LDAP_SERVER_URL=ldap://ldap.example.com:389
			- LDAP_BIND_DN=cn=admin,dc=example,dc=com
			- LDAP_BIND_CREDENTIALS=admin
			- LDAP_SEARCH_BASE=ou=users,dc=example,dc=com
			- LDAP_GROUP_FILTER=(memberOf=cn={{group}},ou=Groups,dc=example,dc=com)
			# LDAP optional
			- LDAP_SYNC_ENABLED=true
			- LDAP_SYNC_CRON=0 */1 * * *
			- LDAP_SEARCH_FILTER=(sAMAccountName={{username}})
			- LDAP_USER_OBJECT_CLASSES=user,person

	db:
		image: postgres:17
		environment:
			- POSTGRES_USER=${POSTGRES_USER:-postgres}
			- POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
			- POSTGRES_DB=${POSTGRES_DB:-postgres}
		volumes:
			- ${POSTGRES_DATA_PATH:-postgres_data}:/var/lib/postgresql/data
		ports:
			- "5432:5432"
		healthcheck:
			test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
			interval: 10s
			timeout: 5s
			retries: 5

volumes:
	app_data:
	postgres_data:
```

### Verwendung mit Umgebungsvariablen

Erstellen Sie z.B. eine `.env` Datei im gleichen Verzeichnis wie die `docker-compose.yml`:

```bash
# .env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=postgres

# Optional: Pfade für persistente Daten auf dem Host-System
# Wenn nicht gesetzt, werden Docker Volumes verwendet
APP_DATA_PATH=./data/app
POSTGRES_DATA_PATH=./data/postgres
```

Starten Sie die Container:

```bash
docker-compose up -d
```

Die Anwendung ist nach dem Build unter `http://localhost` erreichbar.

## Hinweise

- Die Umgebungsvariablen können nach Bedarf angepasst werden.
- **Datenpersistierung:**
  - **Anwendungsdaten**: Templates und andere App-Daten werden im Volume `app_data` gespeichert
  - **Datenbankdaten**: PostgreSQL-Daten werden im Volume `postgres_data` gespeichert
- Für Produktion sollten Passwörter und Secrets angepasst werden.

## Datenverzeichnis-Struktur

```text
/data
	/templates   # Enthält Vorlagen für Prüfungen und Abschnitte
```

## Persistente Daten

Die Anwendung verwendet zwei verschiedene Volumes für persistente Daten:

- **`app_data`**: Speichert Anwendungsdaten wie Templates, Logs und generierte Dateien
- **`postgres_data`**: Speichert die PostgreSQL-Datenbankdateien

### Konfiguration der Speicherpfade

Standardmäßig werden Docker Volumes verwendet. Sie können jedoch über Umgebungsvariablen eigene Host-Pfade definieren:

```bash
# Beispiel für Host-Pfade statt Docker Volumes
APP_DATA_PATH=./data/app          # Anwendungsdaten
POSTGRES_DATA_PATH=./data/postgres # Datenbankdaten
```

**Hinweis**: Stellen Sie sicher, dass die angegebenen Verzeichnisse existieren und die entsprechenden Berechtigungen haben.

---

**Hinweis:** Für produktive Umgebungen sollten alle Passwörter und Secrets sicher gesetzt werden.
