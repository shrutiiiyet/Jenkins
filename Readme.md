# Jenkins (Docker) — COC Ecosystem

Lightweight repository containing Jenkins infrastructure and the **all-in-one pipeline runner** for the COC Ecosystem.

## Contents
- `Dockerfile` — build instructions for the Jenkins master image (Docker-in-Docker CLI).
- `Jenkinsfile` — declarative pipeline that orchestrates all COC services.
- `docker-compose.ecosystem.yml` — unified compose file for the full ecosystem.
- `pg2mysql.sh` — converts the PostgreSQL seed dump to MySQL-compatible SQL.
- `seed/dump.sql` — PostgreSQL seed data.


## Prerequisites
- Docker (tested on Docker Engine 20.10+)
- Jenkins 2.x with **Pipeline**, **Docker Pipeline**, and **Blue Ocean** plugins

---

## Quick Start — Jenkins Master + Agent

### 1. Create the Docker network

```bash
docker network create jenkins
```

### 2. Build and run the Jenkins master

```bash
docker build -t jenkins-custom:latest .

docker run -d --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  --network jenkins \
  jenkins-custom:latest
```

### 3. Start the SSH agent node

```bash
  docker run -d --rm --name=agent1 -p 22:22 -e "JENKINS_AGENT_SSH_PUBKEY=<YOUR_PUBLIC_SSH_KEY>" jenkins/ssh-agent:alpine-jdk21
```

> **Note**: The agent needs Docker socket access (`-v /var/run/docker.sock:/var/run/docker.sock`) to run `docker compose` commands from the pipeline.

### 4. Access Jenkins at `http://localhost:8080`

---

## Setting Up the Pipeline Job

### Step 1: Create the Job

1. Go to **New Item** → **Pipeline** → Name: `COC-Ecosystem`
2. Under **Pipeline** → Definition: **Pipeline script from SCM**
3. **SCM**: Git → Repository URL: `<this repo's URL>`
4. **Script Path**: `Jenkinsfile`
5. Click **Save**

### Step 2: Run with Parameters

Click **Build with Parameters**. The following parameters are available in the Jenkins UI:

| Parameter | Type | Description |
|-----------|------|-------------|
| `DB_ENGINE` | Choice | `postgres` or `mysql` — which database to spin up |
| `SEED_DB` | Boolean | Whether to seed the database with initial data |
| `JWT_SECRET` | Password | JWT signing secret for backends |
| `REFRESH_SECRET` | Password | Refresh token secret |
| `SALTING` | Password | Password salting value |
| `EMAIL_ID` | String | Email for notifications |
| `CONTACT_EMAIL_ID` | String | Contact email (admin) |
| `RESEND_API_KEY` | Password | Resend email API key |
| `GOOGLE_CLIENT_ID` | String | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Password | Google OAuth secret |
| `GITHUB_CLIENT_ID` | String | GitHub OAuth client ID |
| `GITHUB_CLIENT_SECRET` | Password | GitHub OAuth secret |
| `SUPABASE_URL` | String | Supabase URL (optional) |
| `SUPABASE_SERVICE_ROLE_KEY` | Password | Supabase key (optional) |

> **Ports and DB credentials are hardcoded** — no user input needed for those.

### Step 3: Verify Services

After a successful build:

| Service | URL |
|---------|-----|
| COC API | http://localhost:3000 |
| Member Frontend | http://localhost:5174 |
| Admin Frontend | http://localhost:5173 |
| Member Backend | http://localhost:3001 |
| Admin Backend | http://localhost:8000 |

---

## Pipeline Stages

```
1. Cleanup Previous Run  — tears down any leftover containers
2. Pull DockerHub Images — pulls all 5 pre-built images
3. Start Database        — spins up postgres OR mysql
4. Wait for Database     — health check loop
5. Seed Database         — loads dump.sql (postgres) or dump_mysql.sql (mysql)
6. Start COC API         — connects API to database
7. Wait for API Health   — /health endpoint check
8. Start Member Services — member backend + frontend
9. Start Admin Services  — admin backend + frontend
10. Ecosystem Health Check — verifies all services respond
```

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Jenkins Agent                   │
│                                                  │
│  ┌──────────┐   ┌──────────────────────────────┐│
│  │ postgres  │   │         coc-api              ││
│  │ OR mysql  │◄──│   :3000 (/health)            ││
│  │  :5432    │   └──────────┬───────────────────┘│
│  │  :3306    │              │                    │
│  └──────────┘              │                    │
│                  ┌─────────┴──────────┐         │
│          ┌──────┴──────┐    ┌────────┴───────┐  │
│          │member-backend│    │ admin-backend  │  │
│          │   :3001      │    │   :8000        │  │
│          └──────┬──────┘    └────────┬───────┘  │
│          ┌──────┴──────┐    ┌────────┴───────┐  │
│          │member-frontend   │ admin-frontend │  │
│          │   :5174      │    │   :5173        │  │
│          └─────────────┘    └────────────────┘  │
│                                                  │
│              coc-network (bridge)                │
└─────────────────────────────────────────────────┘
```

---

## Stopping the Ecosystem

```bash
COMPOSE_PROFILES=postgres,mysql \
docker compose -f docker-compose.ecosystem.yml -p coc-ecosystem down --volumes
```
