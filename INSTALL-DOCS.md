# BAS Wissen - Installation & Deployment auf VServer

Diese Anleitung beschreibt die Installation und Konfiguration der BAS Wissen Plattform auf einem Ubuntu LTS VServer mit eigener Domain und SSL-Zertifikat.

## Inhaltsverzeichnis

1. [Hardware-Anforderungen](#hardware-anforderungen)
2. [Systemvoraussetzungen](#systemvoraussetzungen)
3. [Server-Setup](#server-setup)
4. [SSL-Zertifikat Integration](#ssl-zertifikat-integration)
5. [Deployment Konfiguration](#deployment-konfiguration)
6. [Installation](#installation)
7. [Backup-Strategie](#backup-strategie)
8. [Monitoring & Wartung](#monitoring--wartung)
9. [Update-Prozedur](#update-prozedur)
10. [Troubleshooting](#troubleshooting)

---

## Hardware-Anforderungen

### Nutzungsanalyse

Das System ist für folgende Szenarien ausgelegt:

- **Erwartete aktive Nutzer**: 150
- **Gleichzeitige Nutzer (Normal)**: 15-30 (10-20%)
- **Gleichzeitige Nutzer (Peak)**: 40-80

### Empfohlene Konfiguration

| Ressource | Spezifikation |
|-----------|---------------|
| **vCPUs** | 8 |
| **RAM** | 16 GB |
| **Storage (OS)** | 40 GB SSD |
| **External Storage** | ≥ 20 GB (skalierbar für Video-Daten) |

**Hinweis:** Die External Storage wird für Video-Uploads und deren transkodierte Varianten (Desktop/Mobile) benötigt. Der Speicherbedarf wächst mit der Anzahl und Länge der hochgeladenen Videos. Die CPU-Anforderung von 8 vCPUs unterstützt die parallele Video-Transkodierung mit ffmpeg.

---

## Systemvoraussetzungen

- **Betriebssystem**: Ubuntu 24.04 LTS
- **Root-Zugriff** oder sudo-Berechtigungen
- **Offene Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **Domain**: Eigene Domain mit DNS-Konfiguration
- **SSL-Zertifikat**: PEM-Format (cert.pem + key.pem)
- **LDAP-Zugang**: LDAP-Server für Benutzerauthentifizierung

---

## Server-Setup

### 1. Basis-Installation

```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Essenzielle Pakete installieren
sudo apt install -y curl wget git nano ufw logrotate
```

- [x] Tested

### 2. Docker Installation

```bash
# Docker aus Ubuntu Repository installieren
sudo apt install -y docker.io docker-compose-v2

# Docker-Dienst starten und aktivieren
sudo systemctl start docker
sudo systemctl enable docker

# Benutzer zur Docker-Gruppe hinzufügen
sudo usermod -aG docker $USER

# Abmelden und neu anmelden, damit Gruppenzugehörigkeit wirksam wird
```

- [x] Tested

**Docker Installation verifizieren:**

```bash
# Nach erneutem Login:
docker --version
docker compose version
```

- [x] Tested

### 3. Firewall konfigurieren

```bash
# Firewall-Regeln einrichten
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# Firewall aktivieren
sudo ufw enable

# Status prüfen
sudo ufw status verbose
```

- [x] Tested

### 4. Verzeichnisstruktur erstellen

```bash
# Arbeitsverzeichnis erstellen
sudo mkdir -p /opt/bas-wissen
cd /opt/bas-wissen

# Datenverzeichnisse anlegen
sudo mkdir -p data/{postgres,ssl,backups,logs/caddy}

# Berechtigungen setzen
sudo chown -R $USER:$USER /opt/bas-wissen
chmod 755 data
```

- [x] Tested

### 5. Externes Volume für Video-Storage einbinden

Das externe Volume wird für Video-Uploads und deren transkodierte Varianten benötigt.

#### Mount etc.
```bash
# Externes Volume mounten (Beispiel)
# Volume formatieren (nur beim ersten Mal!)
sudo mkfs.ext4 /dev/vdb

# Mount-Point erstellen
sudo mkdir -p /mnt/bas-wissen-videos

# Volume mounten
sudo mount /dev/vdb /mnt/bas-wissen-videos

# Automatisches Mounten bei Systemstart konfigurieren
# UUID des Volumes ermitteln
sudo blkid /dev/vdb

# Eintrag in /etc/fstab hinzufügen (UUID aus vorherigem Befehl verwenden)
# Beispiel:
# UUID=xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /mnt/bas-wissen-videos ext4 defaults 0 2
echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb) /mnt/bas-wissen-videos ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### Verzeichnisstruktur und Soft-Link

```bash
# Verzeichnis für Videos im externen Volume erstellen
sudo mkdir -p /mnt/bas-wissen-videos/videos

# Berechtigungen setzen
sudo chown -R $USER:$USER /mnt/bas-wissen-videos

# Symlink im Datenverzeichnis erstellen
ln -s /mnt/bas-wissen-videos/videos /opt/bas-wissen/data/videos

# Symlink verifizieren
ls -la /opt/bas-wissen/data/
```

---

## SSL-Zertifikat Integration

### 1. Zertifikate bereitstellen

Der Kunde stellt folgende Dateien bereit:

- **cert.pem**: SSL-Zertifikat (Full Chain)
- **key.pem**: Private Key

```bash
# Zertifikate in SSL-Verzeichnis kopieren
sudo cp /pfad/zum/cert.pem /opt/bas-wissen/data/ssl/cert.pem
sudo cp /pfad/zum/key.pem /opt/bas-wissen/data/ssl/key.pem
```

---

#### ⚠️NUR ZUM TESTEN Selfsigned Zertifikat erstellen⚠️

```bash
cd /opt/bas-wissen/data/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout key.pem \
-out cert.pem \
-subj "/C=DE/ST=SN/L=Leipzig/O=Meetle GmbH/OU=Nachhall Ops/CN=bas-wissen.meetle.dev" \
-addext "subjectAltName=DNS:bas-pg-test.meetle.dev"
```

**Self-Signed Zertifikat im Browser trotz HSTS etc. akzeptieren:**

- **Chrome**: Auf der Fehlerseite `thisisunsafe` tippen (ohne Eingabefeld)

---

#### ‼️WICHTIG: Zugriffsrechte
```bash
# Berechtigungen einschränken (wichtig für Sicherheit!)
sudo chmod 600 /opt/bas-wissen/data/ssl/*.pem
sudo chown root:root /opt/bas-wissen/data/ssl/*.pem
```

#### Cert Prüfen
```bash
# Gültigkeit prüfen
openssl x509 -in /opt/bas-wissen/data/ssl/cert.pem -noout -dates

# Subject und Issuer anzeigen
openssl x509 -in /opt/bas-wissen/data/ssl/cert.pem -noout -subject -issuer

# Alle Details anzeigen
openssl x509 -in /opt/bas-wissen/data/ssl/cert.pem -text -noout
```

- [x] Tested

### 2. Caddyfile für Production erstellen

```bash
# Caddyfile anlegen
nano /opt/bas-wissen/Caddyfile
```

**Inhalt:**

```caddyfile
{
    auto_https off
}

:443 {
    tls /ssl/cert.pem /ssl/key.pem

    # Backend API (inkl. Video-Streaming & Upload-Transcoding)
    handle /api/* {
        uri strip_prefix /api
        reverse_proxy localhost:3000 {
            # Buffering deaktivieren für Video-Streaming
            flush_interval -1
        }
    }

    # Frontend (SPA)
    handle /* {
        root * /app/web
        try_files {path} /index.html
        file_server
    }

    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }

    # Security Headers
    header {
        # HSTS (1 Jahr)
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Clickjacking-Schutz
        X-Frame-Options "SAMEORIGIN"
        # XSS-Schutz
        X-Content-Type-Options "nosniff"
        # Referrer Policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# HTTP -> HTTPS Redirect
:80 {
    redir https://{host}{uri} permanent
}
```

- [x] Tested

---

## Deployment Konfiguration

### 1. docker-compose.yml erstellen

```bash
nano /opt/bas-wissen/docker-compose.yml
```

**Inhalt:**

```yaml
services:
  app:
    image: ghcr.io/campus-12/bas-wissen-container:latest
    container_name: bas-wissen-app
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      # Video Storage (Symlink zu externem Volume)
      - ./data/videos:/data/videos
      # Custom Caddyfile mit SSL
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      # SSL-Zertifikate
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
      - NODE_OPTIONS=--max-old-space-size=2048

      # Database
      - DATABASE_TYPE=postgres
      - DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable

      # JWT Configuration
      - JWT_SECRET=${JWT_SECRET}
      - JWT_ACCESS_TOKEN_EXPIRES_IN=${JWT_ACCESS_TOKEN_EXPIRES_IN:-45m}
      - JWT_REFRESH_TOKEN_EXPIRES_IN=${JWT_REFRESH_TOKEN_EXPIRES_IN:-5d}

      # Application Name
      - APP_NAME=BAS Wissen

      # Video Storage & Processing
      - VIDEO_STORAGE_PATH=/data/videos
      - VIDEO_ALLOWED_MIME_TYPES=${VIDEO_ALLOWED_MIME_TYPES:-video/mp4,video/webm,video/ogg,video/quicktime}
      - VIDEO_DESKTOP_MAX_WIDTH=${VIDEO_DESKTOP_MAX_WIDTH:-1920}
      - VIDEO_DESKTOP_CRF=${VIDEO_DESKTOP_CRF:-22}
      - VIDEO_DESKTOP_AUDIO_BITRATE=${VIDEO_DESKTOP_AUDIO_BITRATE:-128k}
      - VIDEO_MOBILE_MAX_WIDTH=${VIDEO_MOBILE_MAX_WIDTH:-720}
      - VIDEO_MOBILE_CRF=${VIDEO_MOBILE_CRF:-26}
      - VIDEO_MOBILE_AUDIO_BITRATE=${VIDEO_MOBILE_AUDIO_BITRATE:-96k}

      # LDAP Configuration
      - LDAP_SERVER_URL=${LDAP_SERVER_URL}
      - LDAP_BIND_DN=${LDAP_BIND_DN}
      - LDAP_BIND_CREDENTIALS=${LDAP_BIND_CREDENTIALS}
      - LDAP_SEARCH_BASE=${LDAP_SEARCH_BASE}
      - 'LDAP_SEARCH_FILTER=(sAMAccountName={{username}})'
      - LDAP_TIMEOUT_MS=${LDAP_TIMEOUT_MS:-10000}
      - LDAP_CONNECT_TIMEOUT_MS=${LDAP_CONNECT_TIMEOUT_MS:-10000}

      # Optional: CORS & Cookie Configuration
      - FRONTEND_ORIGINS=${FRONTEND_ORIGINS:-}
      - ALLOW_NO_ORIGIN=${ALLOW_NO_ORIGIN:-true}
      - COOKIE_DOMAIN=${COOKIE_DOMAIN:-}

      # Optional: Debug Flags
      - DEBUG_LDAP=${DEBUG_LDAP:-0}
    healthcheck:
      test: ["CMD", "wget", "--no-check-certificate", "--spider", "-q", "https://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - bas-network

  db:
    image: postgres:17-alpine
    container_name: bas-wissen-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=en_US.UTF-8
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
      - bas-network
    command:
      - "postgres"
      # Performance Tuning (PostgreSQL nutzt ~4GB, Rest für Node.js + ffmpeg)
      - "-c"
      - "shared_buffers=1GB"           # 25% von 4GB (für DB reserviert)
      - "-c"
      - "effective_cache_size=3GB"     # 75% von 4GB
      - "-c"
      - "work_mem=16MB"
      - "-c"
      - "maintenance_work_mem=256MB"
      - "-c"
      - "random_page_cost=1.1"         # Optimiert für SSD
      - "-c"
      - "effective_io_concurrency=200" # SSD-optimiert
      - "-c"
      - "log_timezone=UTC"
      - "-c"
      - "timezone=UTC"
      # Audit Logging (optional, auskommentiert für Production)
      # - "-c"
      # - "log_statement=mod"            # Log INSERT/UPDATE/DELETE
      # - "-c"
      # - "log_duration=on"              # Log Query-Ausführungszeit

networks:
  bas-network:
    driver: bridge
```

- [x] Tested

### 2. Environment-Variablen konfigurieren

```bash
nano /opt/bas-wissen/.env
```

**Inhalt (.env):**

```bash
# ========================================
# PostgreSQL Configuration
# ========================================
POSTGRES_USER=bas_user
POSTGRES_PASSWORD=<HIER_SICHERES_PASSWORT_EINTRAGEN>
POSTGRES_DB=bas_wissen

# ========================================
# JWT Configuration
# ========================================
JWT_SECRET=<HIER_JWT_SECRET_EINTRAGEN>
JWT_ACCESS_TOKEN_EXPIRES_IN=45m
JWT_REFRESH_TOKEN_EXPIRES_IN=5d

# ========================================
# Application Configuration
# ========================================
# APP_ENV=develop  # Uncomment to enable Swagger UI at /api
APP_ENV=production

# ========================================
# Video Processing Configuration
# ========================================
# Video file types
VIDEO_ALLOWED_MIME_TYPES=video/mp4,video/webm,video/ogg,video/quicktime

# Desktop quality settings
VIDEO_DESKTOP_MAX_WIDTH=1920
VIDEO_DESKTOP_CRF=22
VIDEO_DESKTOP_AUDIO_BITRATE=128k

# Mobile quality settings
VIDEO_MOBILE_MAX_WIDTH=720
VIDEO_MOBILE_CRF=26
VIDEO_MOBILE_AUDIO_BITRATE=96k

# ========================================
# LDAP Configuration
# ========================================
# LDAP Server URL
LDAP_SERVER_URL=ldap://188.245.245.81:1389
# oder für LDAPS:
# LDAP_SERVER_URL=ldaps://kunde-ldap.domain.de:636

# Service Account für LDAP-Bind
LDAP_BIND_DN=cn=admin,dc=miracode,dc=io
LDAP_BIND_CREDENTIALS=<LDAP_SERVICE_PASSWORD>

# Benutzersuche
LDAP_SEARCH_BASE=ou=users,dc=miracode,dc=io

# LDAP Timeouts (optional, Defaults: 10000ms)
# LDAP_TIMEOUT_MS=10000
# LDAP_CONNECT_TIMEOUT_MS=10000

# ========================================
# LDAP Gruppen (nur zur Dokumentation)
# ========================================
# Die folgenden Gruppen sind im Backend hardcoded:
# - SG_BAS-Wissen-Admin   (Volle Rechte)
# - SG_BAS-Wissen-Creator (Kann Videos hochladen und verwalten)
# - SG_BAS-Wissen-User    (Kann Videos anschauen)

# ========================================
# Optional: CORS & Cookie Configuration
# ========================================
FRONTEND_ORIGINS=https://andere-domain.de
# nur bei abweichenden domains
# COOKIE_DOMAIN=.bas.de

# ========================================
# Optional: Debug Flags
# ========================================
# DEBUG_LDAP=1  # Aktiviert zusätzliche LDAP-Logs
```

- [x] Tested

### 3. Secrets generieren

**Sichere Passwörter und Secrets erstellen:**

```bash
# PostgreSQL Passwort (32 Zeichen)
echo "POSTGRES_PASSWORD=$(openssl rand -hex 32)"

# JWT Secret (64 Zeichen)
echo "JWT_SECRET=$(openssl rand -base64 64)"
```

- [x] Tested

**Wichtig:** Kopieren Sie die generierten Werte in die `.env` Datei.

### 4. Berechtigungen setzen

```bash
# .env-Datei vor unbefugtem Zugriff schützen
chmod 600 /opt/bas-wissen/.env
```

- [x] Tested

---

## Installation

### 1. GitHub Container Registry Login

```bash
# GitHub Token für campus-12 image repo
 export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Login durchführen (username für ghcr egal für docker cli aber benötigt)
echo $GITHUB_TOKEN | docker login ghcr.io -u - --password-stdin
```

- [x] Tested

### 2. Docker Image pullen

```bash
cd /opt/bas-wissen

# Image herunterladen
docker pull ghcr.io/campus-12/bas-wissen-container:latest
```

- [x] Tested

### 3. Container starten

```bash
# Container im Hintergrund starten
docker compose -f docker-compose.yml --env-file .env up -d

# Logs überwachen
docker compose -f docker-compose.yml logs -f
```

- [ ] Tested

### 4. Installation verifizieren

**Prüfen Sie folgende Punkte:**

```bash
# 1. Container-Status
docker compose -f docker-compose.yml ps

# Erwartete Ausgabe:
# NAME               IMAGE                                       STATUS
# bas-wissen-app     ghcr.io/campus-12/bas-wissen-container     Up (healthy)
# bas-wissen-db      postgres:17-alpine                         Up (healthy)

# 2. Backend-API testen
curl -k https://ihre-domain.de/api/

# Erwartete Ausgabe: "Hello World!"

# 3. Frontend testen (im Browser)
# https://ihre-domain.de

# 4. Swagger-Dokumentation (nur wenn APP_ENV=develop)
# https://ihre-domain.de/api/docs
```

- [x] Tested

### 5. Erste Schritte nach Installation

**Test-Login durchführen:**

1. Browser öffnen: `https://ihre-domain.de`
2. Mit LDAP-Credentials einloggen
3. Prüfen, ob Benutzerrolle korrekt zugewiesen wurde

- [x] Tested

## Backup-Strategie

### 1. Automatisches Backup-Script erstellen

```bash
nano /opt/bas-wissen/backup.sh
```

**Inhalt:**

```bash
#!/bin/bash
#
# BAS Wissen - Backup Script
# Führt tägliche Backups von Datenbank und Video-Daten durch
#

set -e  # Bei Fehler abbrechen

BACKUP_DIR="/opt/bas-wissen/data/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
COMPOSE_FILE="/opt/bas-wissen/docker-compose.yml"

echo "=========================================="
echo "BAS Backup gestartet: $(date)"
echo "=========================================="

# PostgreSQL Dump
echo "Erstelle PostgreSQL Backup..."
docker compose -f "$COMPOSE_FILE" exec -T db \
  pg_dump -U bas_user -d bas_wissen \
  --format=custom \
  --compress=9 \
  > "$BACKUP_DIR/db_backup_$DATE.dump"

# Alternativ: SQL-Format
#docker compose -f "$COMPOSE_FILE" exec -T db \
#  pg_dump -U bas_user -d bas_wissen | \
#  gzip > "$BACKUP_DIR/db_backup_$DATE.sql.gz"

echo "PostgreSQL Backup erstellt: db_backup_$DATE.dump"

# HINWEIS: Video-Daten werden NICHT gesichert
# - Videos liegen auf externem Volume
# - Zu groß für reguläre Backups
# - Separate Backup-Strategie auf Storage-Ebene erforderlich
echo "Video-Daten: Nicht in diesem Backup enthalten (externes Volume)"

# Alte Backups löschen (älter als RETENTION_DAYS)
echo "Lösche alte Backups (älter als $RETENTION_DAYS Tage)..."
find "$BACKUP_DIR" -type f \( -name "*.dump" -o -name "*.sql.gz" -o -name "*.tar.gz" \) \
  -mtime +$RETENTION_DAYS -delete

# Backup-Größe ausgeben
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Gesamte Backup-Größe: $BACKUP_SIZE"

echo "=========================================="
echo "BAS Backup abgeschlossen: $(date)"
echo "=========================================="
```

- [x] Tested


**Script ausführbar machen:**

```bash
chmod +x /opt/bas-wissen/backup.sh
```

- [x] Tested

### 2. Cron-Job für automatische Backups

⚠️ Nur anlegen, wenn kein täglicher maintenance.sh-Job (siehe weiter unten) angelegt wird.

```bash
# Crontab bearbeiten
crontab -e

# Folgenden Eintrag hinzufügen:
# Backup täglich um 3:00 Uhr
0 3 * * * /opt/bas-wissen/backup.sh >> /var/log/bas-backup.log 2>&1
```

- [x] Tested

### 3. Backup wiederherstellen

**Datenbank wiederherstellen:**

```bash
# Container stoppen
docker compose -f docker-compose.yml stop app

# Datenbank aus Custom-Format wiederherstellen
docker compose -f docker-compose.yml exec -T db \
  pg_restore -U bas_user -d bas_wissen --clean --if-exists \
  < /opt/bas-wissen/data/backups/db_backup_YYYYMMDD_HHMMSS.dump

# Container neu starten
docker compose -f docker-compose.yml start app
```

- [x] Tested

**Video-Daten wiederherstellen:**

⚠️ **Hinweis:** Video-Daten werden nicht durch das Backup-Script gesichert, da sie auf einem externen Volume liegen. Für die Wiederherstellung von Video-Daten eigene Backup-Restore-Lösung verwenden.

---

## Monitoring & Wartung

### 1. Log-Rotation konfigurieren

```bash
sudo nano /etc/logrotate.d/bas-wissen
```

**Inhalt:**

```
/opt/bas-wissen/data/logs/caddy/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0640 root root
    sharedscripts
    postrotate
        docker compose -f /opt/bas-wissen/docker-compose.yml exec app killall -HUP caddy 2>/dev/null || true
    endscript
}

/var/log/bas-backup.log {
    weekly
    rotate 8
    compress
    delaycompress
    notifempty
    missingok
    create 0640 root root
}
```


- [x] Tested

### 2. Healthcheck-Script

```bash
nano /opt/bas-wissen/healthcheck.sh
```

**Inhalt:**

```bash
#!/bin/bash
#
# Healthcheck-Script
#

DOMAIN="https://localhost"
TIMEOUT=10

# Backend API prüfen
if curl -k -f -m $TIMEOUT "$DOMAIN/api/" > /dev/null 2>&1; then
    echo "OK: Application is healthy"
    exit 0
else
    echo "CRITICAL: Application is down"
    exit 2
fi
```

```bash
chmod +x /opt/bas-wissen/healthcheck.sh

/opt/bas-wissen/healthcheck.sh
```

Output:
```
OK: Application is healthy
```


- [x] Tested

### 3. Wichtige Monitoring-Befehle

```bash
# Container-Status prüfen
docker compose -f docker-compose.yml ps

# Live-Logs anzeigen
docker compose -f docker-compose.yml logs -f app
docker compose -f docker-compose.yml logs -f db

# Ressourcenverbrauch
docker stats bas-wissen-app bas-wissen-db

# Festplattenplatz prüfen
df -h /opt/bas-wissen
du -sh /opt/bas-wissen/data/*

# PostgreSQL-Statistiken
docker compose -f docker-compose.yml exec db \
  psql -U bas_user -d bas_wissen -c "
    SELECT schemaname, tablename,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10;
  "
```

### 4. Wartungsfenster-Skript

```bash
nano /opt/bas-wissen/maintenance.sh
```

**Inhalt:**

```bash
#!/bin/bash
#
# Wartungsarbeiten durchführen
#

set -e

echo "=== Wartung gestartet: $(date) ==="

# 1. Backup erstellen
/opt/bas-wissen/backup.sh

# 2. Docker Images aufräumen
echo "Räume alte Docker Images auf..."
docker image prune -af --filter "until=720h"  # 30 Tage

# 3. Docker Volumes prüfen
echo "Prüfe Docker Volumes..."
docker volume ls -qf dangling=true | xargs -r docker volume rm

# 4. PostgreSQL VACUUM
echo "Führe PostgreSQL VACUUM durch..."
docker compose -f /opt/bas-wissen/docker-compose.yml exec db \
  psql -U bas_user -d bas_wissen -c "VACUUM ANALYZE;"

echo "=== Wartung abgeschlossen: $(date) ==="
```

```bash
chmod +x /opt/bas-wissen/maintenance.sh

# Wöchentliche Ausführung (Sonntag 4 Uhr)
crontab -e
# 0 4 * * 0 /opt/bas-wissen/maintenance.sh >> /var/log/bas-maintenance.log 2>&1
```

- [x] Tested

---

## Update-Prozedur

### Update mit Downtime

```bash
# 1. Backup erstellen
./backup.sh

# 2. Container stoppen
docker compose -f docker-compose.yml down

# 3. Aktuelles Image für Rollback sichern
docker tag ghcr.io/campus-12/bas-wissen-container:latest \
           ghcr.io/campus-12/bas-wissen-container:backup-$(date +%Y%m%d%H%M%S)

# 4. Neues Image pullen
docker pull ghcr.io/campus-12/bas-wissen-container:latest

# 5. Container neu starten
docker compose -f docker-compose.yml --env-file .env up -d

# 6. Logs prüfen
docker compose -f docker-compose.yml logs -f

# 7. Funktionstest durchführen
./healthcheck.sh
```

- [ ] Tested

### Rollback durchführen

```bash
# Falls Update fehlschlägt: Rollback auf vorherige Version

# 1. Verfügbare Images anzeigen
docker images | grep bas-wissen-container

# Erwartete Ausgabe:
# ghcr.io/campus-12/bas-wissen-container   latest              abc123456789   1 hour ago    512MB
# ghcr.io/campus-12/bas-wissen-container   backup-20251216...  2b62809e356e   7 days ago    508MB

# 2. Container stoppen
docker compose -f docker-compose.yml down

# 3. Alte Version in docker-compose.yml aktivieren
# Option A: Backup-Tag verwenden (wenn vorhanden)
#   image: ghcr.io/campus-12/bas-wissen-container:backup-20251216123045
#
# Option B: Image-ID verwenden (immer verfügbar)
#   image: 2b62809e356e
nano docker-compose.yml

# 4. Alte Datenbank wiederherstellen (falls nötig, siehe Backup-Sektion)

# 5. Container mit alter Version starten
docker compose -f docker-compose.yml --env-file .env up -d
```

- [ ] Tested

---

## Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker compose -f docker-compose.yml logs app db

# Häufige Probleme:
# - Falsche Environment-Variablen in .env
# - Datenbank nicht erreichbar
# - Ports bereits belegt

# Ports prüfen
sudo netstat -tulpn | grep -E ':(80|443|5432)'

# Container-Konfiguration testen
docker compose -f docker-compose.yml config
```

### Datenbank-Verbindungsfehler

```bash
# PostgreSQL-Logs prüfen
docker compose -f docker-compose.yml logs db

# In Container einloggen und Verbindung testen
docker compose -f docker-compose.yml exec app sh
wget -O- http://db:5432  # Sollte PostgreSQL-Response zeigen

# Direkt zur Datenbank verbinden
docker compose -f docker-compose.yml exec db \
  psql -U bas_user -d bas_wissen
```

### LDAP-Authentifizierung funktioniert nicht

```bash
# LDAP-Konfiguration prüfen
docker compose -f docker-compose.yml exec app env | grep LDAP

# LDAP-Verbindung testen (ldapsearch Tool im Container)
docker compose -f docker-compose.yml exec app sh
# apk add openldap-clients
# ldapsearch -x -H "$LDAP_SERVER_URL" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_CREDENTIALS" -b "$LDAP_SEARCH_BASE"

# Backend-Logs nach LDAP-Fehlern durchsuchen
docker compose -f docker-compose.yml logs app | grep -i ldap
```

### SSL-Zertifikat-Fehler

```bash
# Zertifikat-Dateien prüfen
ls -la /opt/bas-wissen/data/ssl/

# Zertifikat-Gültigkeit prüfen
openssl x509 -in /opt/bas-wissen/data/ssl/cert.pem -noout -dates -subject

# Caddyfile-Syntax prüfen
docker compose -f docker-compose.yml exec app caddy validate --config /etc/caddy/Caddyfile

# Caddy-Logs prüfen
docker compose -f docker-compose.yml logs app | grep -i caddy
```

### Hohe Ressourcennutzung

```bash
# Ressourcenverbrauch überwachen
docker stats bas-wissen-app bas-wissen-db

# PostgreSQL Query-Performance analysieren
docker compose -f docker-compose.yml exec db \
  psql -U bas_user -d bas_wissen -c "
    SELECT pid, usename, application_name, state, query, query_start
    FROM pg_stat_activity
    WHERE state != 'idle'
    ORDER BY query_start;
  "

# Langsame Queries identifizieren (pg_stat_statements Extension erforderlich)
docker compose -f docker-compose.yml exec db \
  psql -U bas_user -d bas_wissen -c "
    SELECT query, calls, total_exec_time, mean_exec_time
    FROM pg_stat_statements
    ORDER BY mean_exec_time DESC
    LIMIT 10;
  "
```

### Speicherplatz voll

```bash
# Speicherverbrauch analysieren
du -sh /opt/bas-wissen/data/*

# Alte Logs löschen
find /opt/bas-wissen/data/logs -name "*.log" -mtime +30 -delete

# Alte Backups löschen
find /opt/bas-wissen/data/backups -mtime +30 -delete

# Docker aufräumen
docker system prune -af
docker volume prune -f
```

### In Container einloggen für Debugging

```bash
# In App-Container
docker compose -f docker-compose.yml exec app sh

# In DB-Container
docker compose -f docker-compose.yml exec db sh

# Als root (falls nötig)
docker compose -f docker-compose.yml exec -u root app sh
```

---

## DNS-Konfiguration

### Für den Kunden: DNS A-Record einrichten

```
Hostname: bas-wissen.ihre-domain.de
Type: A
Value: <IP-Adresse des VServers>
TTL: 3600
```

**DNS-Propagation prüfen:**

```bash
# Lokal testen
nslookup bas-wissen.ihre-domain.de

# Weltweit testen
# https://www.whatsmydns.net
```

- [ ] Tested

---

## Sicherheits-Checkliste

Nach der Installation folgende Punkte prüfen:

- [ ] **Firewall (ufw)** ist aktiv mit nur Port 22, 80, 443 offen
- [ ] **SSH** nutzt Key-basierte Authentifizierung (Passwort deaktiviert)
- [ ] **PostgreSQL** ist nur über localhost erreichbar (127.0.0.1:5432)
- [ ] **Starke Passwörter** (min. 32 Zeichen) für PostgreSQL
- [ ] **JWT Secret** hat mindestens 64 Zeichen
- [ ] **SSL-Zertifikate** sind mit chmod 600 geschützt
- [ ] **.env-Datei** ist mit chmod 600 geschützt
- [ ] **APP_ENV** ist auf "production" gesetzt (Swagger nur in "develop" aktiv)
- [ ] **SSL/TLS** läuft mit gültigem Zertifikat
- [ ] **Automatische Backups** sind konfiguriert und getestet
- [ ] **Log-Rotation** ist aktiv
- [ ] **Docker-Container** haben restart-Policy "unless-stopped"
- [ ] **Security Headers** sind in Caddyfile konfiguriert
- [ ] **Monitoring** ist eingerichtet (Healthchecks, Logs)
- [ ] **Externes Video-Volume** ist gemountet und Symlink ist korrekt
- [ ] **LDAP-Gruppen** sind im Active Directory/LDAP angelegt (SG_BAS-Wissen-Admin, SG_BAS-Wissen-Creator, SG_BAS-Wissen-User)

---

**Letzte Aktualisierung**: Dezember 2025
**Version**: 1.0
