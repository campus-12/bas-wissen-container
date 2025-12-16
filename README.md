
# BAS Wissen - Hosting & Deployment

Dieses Projekt stellt ein Docker-Image bereit, das Frontend und Backend von BAS Wissen enthält. Das Image wird automatisch unter `ghcr.io/campus-12/bas-wissen-container:latest` veröffentlicht (siehe GitHub Actions Workflow `.github/workflows/docker-publish.yml`).

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
		image: ghcr.io/campus-12/bas-wissen-container:latest
		container_name: bas-wissen-app
		ports:
			- "80:80"
			- "443:443"
		volumes:
			# Video Storage (symlink to external volume)
			- ./data/videos:/data/videos
			# Custom Caddyfile with SSL
			- ./Caddyfile:/etc/caddy/Caddyfile:ro
			# SSL certificates
			- ./data/ssl:/ssl:ro
			# Logs
			- ./data/logs/caddy:/var/log/caddy
		depends_on:
			db:
				condition: service_healthy
		environment:
			# Node.js Configuration
			- NODE_ENV=production
			- APP_ENV=${APP_ENV:-production}
			- PORT=3000
			
			# Database
			- DATABASE_TYPE=postgres
			- DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
			
			# JWT Configuration
			- JWT_SECRET=${JWT_SECRET}
			- JWT_ACCESS_TOKEN_EXPIRES_IN=45m
			- JWT_REFRESH_TOKEN_EXPIRES_IN=5d
			
			# Video Processing
			- VIDEO_STORAGE_PATH=/data/videos
			- VIDEO_ALLOWED_MIME_TYPES=video/mp4,video/webm,video/ogg,video/quicktime
			
			# LDAP Configuration
			- LDAP_SERVER_URL=${LDAP_SERVER_URL}
			- LDAP_BIND_DN=${LDAP_BIND_DN}
			- LDAP_BIND_CREDENTIALS=${LDAP_BIND_CREDENTIALS}
			- LDAP_SEARCH_BASE=${LDAP_SEARCH_BASE}
			- LDAP_SEARCH_FILTER=(|(sAMAccountName={{username}})(uid={{username}}))
			
			# Optional
			- ALLOW_NO_ORIGIN=true

	db:
		image: postgres:17-alpine
		container_name: bas-wissen-db
		environment:
			- POSTGRES_USER=${POSTGRES_USER}
			- POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
			- POSTGRES_DB=${POSTGRES_DB}
		volumes:
			- ./data/postgres:/var/lib/postgresql/data
		ports:
			- "127.0.0.1:5432:5432"  # Nur localhost-Zugriff
		healthcheck:
			test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
			interval: 10s
			timeout: 5s
			retries: 5

networks:
	bas-network:
		driver: bridge

```

### Verwendung mit Umgebungsvariablen

Erstellen Sie eine `.env` Datei im gleichen Verzeichnis wie die `docker-compose.yml`:

```bash
# .env

# PostgreSQL Configuration
POSTGRES_USER=bas_user
POSTGRES_PASSWORD=<SICHERES_PASSWORT>
POSTGRES_DB=bas_wissen

# JWT Configuration
JWT_SECRET=<JWT_SECRET>

# LDAP Configuration
LDAP_SERVER_URL=ldap://ldap.example.com:389
LDAP_BIND_DN=cn=admin,dc=example,dc=com
LDAP_BIND_CREDENTIALS=<LDAP_PASSWORD>
LDAP_SEARCH_BASE=ou=users,dc=example,dc=com

# Optional: Application Environment
# APP_ENV=develop  # Uncomment to enable Swagger UI
APP_ENV=production
```

Starten Sie die Container:

```bash
docker-compose up -d
```

Die Anwendung ist nach dem Build unter `http://localhost` (oder `https://ihre-domain.de` mit SSL) erreichbar.

## Wichtige Hinweise

- **Secrets generieren**: Verwenden Sie sichere, zufällig generierte Werte für `POSTGRES_PASSWORD` und `JWT_SECRET`
  ```bash
  openssl rand -hex 32  # PostgreSQL Passwort
  openssl rand -base64 64  # JWT Secret
  ```
- **SSL-Zertifikate**: Für HTTPS müssen Sie ein gültiges SSL-Zertifikat in `./data/ssl/` bereitstellen
- **Video-Storage**: Videos werden auf einem externen Volume gespeichert (siehe Produktions-Setup)
- **LDAP-Gruppen**: Die folgenden Gruppen müssen im LDAP/AD existieren:
  - `SG_BAS-Wissen-Admin` (Volle Rechte)
  - `SG_BAS-Wissen-Creator` (Kann Videos hochladen)
  - `SG_BAS-Wissen-User` (Kann Videos anschauen)

## Datenverzeichnis-Struktur

```text
/data
  /videos        # Video-Dateien (Desktop/Mobile Varianten)
  /postgres      # PostgreSQL Datenbank
  /ssl           # SSL-Zertifikate (cert.pem, key.pem)
  /logs/caddy    # Caddy Access Logs
  /backups       # Datenbank-Backups
```

## Persistente Daten

Die Anwendung speichert folgende Daten persistent:

- **`./data/videos`**: Video-Uploads und transkodierte Varianten (symlink zu externem Volume empfohlen)
- **`./data/postgres`**: PostgreSQL-Datenbankdateien
- **`./data/ssl`**: SSL-Zertifikate für HTTPS
- **`./data/logs`**: Anwendungs- und Caddy-Logs
- **`./data/backups`**: Automatische Datenbank-Backups

**Wichtig**: Für Produktionsumgebungen sollte das Video-Storage auf einem separaten, skalierbaren Volume liegen.

## Weitere Dokumentation

Für eine detaillierte Installations- und Deployment-Anleitung siehe [INSTALL-DOCS.md](./INSTALL-DOCS.md).

---

**Hinweis:** Für produktive Umgebungen sollten alle Passwörter und Secrets sicher gesetzt werden. Die vollständige Produktions-Konfiguration ist in [INSTALL-DOCS.md](./INSTALL-DOCS.md) dokumentiert.
