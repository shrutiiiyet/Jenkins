// =============================================================================
// Jenkinsfile — COC-Ecosystem All-in-One Pipeline Runner
//
// Orchestrates the entire COC ecosystem from pre-built DockerHub images.
// Parameterized database selection (PostgreSQL / MySQL), environment variable
// injection, DB seeding, and health-check verification.
//
// Jenkins Job Setup:
//   1. New Item → Pipeline → Name: "COC-Ecosystem"
//   2. Pipeline definition → "Pipeline script from SCM"
//   3. SCM: Git → Repo URL: <this repo>
//   4. Script Path: Jenkinsfile
//   5. Check "This project is parameterized" (auto-detected from parameters{})
// =============================================================================

pipeline {
    agent { label 'agent1' }

    // -------------------------------------------------------------------------
    // Parameters — visible on Jenkins "Build with Parameters" UI
    // -------------------------------------------------------------------------
    parameters {
        choice(
            name: 'DB_ENGINE',
            choices: ['postgres', 'mysql'],
            description: 'Database engine to use for the ecosystem'
        )
        booleanParam(
            name: 'SEED_DB',
            defaultValue: true,
            description: 'Seed the database with initial data (dump.sql)'
        )

        // --- Member Secrets ---
        password(
            name: 'JWT_SECRET_MEMBER',
            defaultValue: '',
            description: 'JWT signing secret for member backend'
        )
        password(
            name: 'REFRESH_SECRET_MEMBER',
            defaultValue: '',
            description: 'Refresh token secret for member backend'
        )
        password(
            name: 'SALTING_MEMBER',
            defaultValue: '',
            description: 'Password salting value for member backend'
        )

        // --- Admin Secrets ---
        password(
            name: 'JWT_SECRET_ADMIN',
            defaultValue: '',
            description: 'JWT signing secret for admin backend'
        )
        password(
            name: 'REFRESH_SECRET_ADMIN',
            defaultValue: '',
            description: 'Refresh token secret for admin backend'
        )
        password(
            name: 'SALTING_ADMIN',
            defaultValue: '',
            description: 'Password salting value for admin backend'
        )

        // --- Email & Notifications ---
        string(
            name: 'EMAIL_ID',
            defaultValue: '',
            description: 'Email ID for sending notifications'
        )
        string(
            name: 'CONTACT_EMAIL_ID',
            defaultValue: '',
            description: 'Contact email for admin panel'
        )
        password(
            name: 'RESEND_API_KEY',
            defaultValue: '',
            description: 'Resend API key for email delivery'
        )

        // --- OAuth — Google ---
        string(
            name: 'GOOGLE_CLIENT_ID',
            defaultValue: '',
            description: 'Google OAuth Client ID (member portal)'
        )
        password(
            name: 'GOOGLE_CLIENT_SECRET',
            defaultValue: '',
            description: 'Google OAuth Client Secret'
        )

        // --- OAuth — GitHub ---
        string(
            name: 'GITHUB_CLIENT_ID',
            defaultValue: '',
            description: 'GitHub OAuth Client ID (member portal)'
        )
        password(
            name: 'GITHUB_CLIENT_SECRET',
            defaultValue: '',
            description: 'GitHub OAuth Client Secret'
        )

        // --- Supabase (optional, for API) ---
        string(
            name: 'SUPABASE_URL',
            defaultValue: '',
            description: 'Supabase project URL (optional, leave empty for local DB)'
        )
        password(
            name: 'SUPABASE_SERVICE_ROLE_KEY',
            defaultValue: '',
            description: 'Supabase service role key (optional)'
        )
    }

    environment {
        // --- Fixed ports (not user-configurable) ---
        API_PORT           = '3000'
        MEMBER_BACKEND_PORT = '3001'
        MEMBER_FRONTEND_PORT = '5174'
        ADMIN_BACKEND_PORT  = '8000'
        ADMIN_FRONTEND_PORT = '5173'

        // --- Fixed DB credentials ---
        POSTGRES_USER     = 'postgres'
        POSTGRES_PASSWORD = 'example'
        POSTGRES_DB       = 'coc'
        MYSQL_ROOT_PASSWORD = 'example'
        MYSQL_DATABASE      = 'coc'

        // --- Compose settings ---
        COMPOSE_PROJECT_NAME = 'coc-ecosystem'
        COMPOSE_FILE         = 'docker-compose.ecosystem.yml'

        // --- Rate limiting defaults ---
        RATE_LIMIT_WINDOW_MINUTES = '15'
        RATE_LIMIT_MAX_REQUESTS   = '100'
        REFRESH_TTL               = '7'
        ACCESS_TTL                = '15'
    }

    stages {

        // =====================================================================
        // Stage 1: Cleanup any previous ecosystem run
        // =====================================================================
        stage('Cleanup Previous Run') {
            steps {
                echo '🧹 Cleaning up any previous ecosystem containers...'
                sh '''
                    COMPOSE_PROFILES=postgres,mysql \
                    docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} down --volumes --remove-orphans 2>/dev/null || true
                '''
            }
        }

        // =====================================================================
        // Stage 2: Pull all images from DockerHub
        // =====================================================================
        stage('Pull DockerHub Images') {
            steps {
                echo '📦 Pulling pre-built images from DockerHub...'
                sh '''
                    docker pull shrutiiiyet/coc-api
                    docker pull shrutiiiyet/coc-member-backend
                    docker pull shrutiiiyet/coc-member-frontend
                    docker pull shrutiiiyet/coc-admin-backend
                    docker pull shrutiiiyet/coc-admin-frontend
                '''
            }
        }

        // =====================================================================
        // Stage 3: Start Database
        // =====================================================================
        stage('Start Database') {
            steps {
                script {
                    def dbProfile = params.DB_ENGINE
                    echo "🗄️  Starting ${dbProfile} database..."

                    if (dbProfile == 'postgres') {
                        env.DATABASE_URL = "postgresql://${env.POSTGRES_USER}:${env.POSTGRES_PASSWORD}@postgres-db:5432/${env.POSTGRES_DB}?sslmode=disable"
                    } else {
                        env.DATABASE_URL = "mysql://root:${env.MYSQL_ROOT_PASSWORD}@mysql-db:3306/${env.MYSQL_DATABASE}"
                    }

                    sh """
                        COMPOSE_PROFILES=${dbProfile} \
                        DATABASE_URL='${env.DATABASE_URL}' \
                        docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} up -d ${dbProfile}-db
                    """
                }
            }
        }

        // =====================================================================
        // Stage 4: Wait for Database to be Healthy
        // =====================================================================
        stage('Wait for Database') {
            steps {
                script {
                    def dbProfile = params.DB_ENGINE
                    def serviceName = "${dbProfile}-db"
                    echo "⏳ Waiting for ${serviceName} to become healthy..."

                    if (dbProfile == 'postgres') {
                        sh """
                            RETRIES=20
                            until docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T postgres-db pg_isready -U postgres -d coc -h 127.0.0.1 -p 5432 -q 2>/dev/null; do
                                RETRIES=\$((RETRIES - 1))
                                if [ \$RETRIES -le 0 ]; then
                                    echo '❌ PostgreSQL did not become healthy in time!'
                                    docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} logs postgres-db
                                    exit 1
                                fi
                                echo "  Waiting... (\$RETRIES retries left)"
                                sleep 3
                            done
                            echo '✅ PostgreSQL is healthy.'
                        """
                    } else {
                        sh """
                            RETRIES=30
                            until docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T mysql-db mysqladmin ping -h 127.0.0.1 -uroot -pexample --silent 2>/dev/null; do
                                RETRIES=\$((RETRIES - 1))
                                if [ \$RETRIES -le 0 ]; then
                                    echo '❌ MySQL did not become healthy in time!'
                                    docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} logs mysql-db
                                    exit 1
                                fi
                                echo "  Waiting... (\$RETRIES retries left)"
                                sleep 3
                            done
                            echo '✅ MySQL is healthy.'
                        """
                    }
                }
            }
        }

        // =====================================================================
        // Stage 5: Seed Database (conditional)
        // =====================================================================
        stage('Seed Database') {
            when {
                expression { return params.SEED_DB }
            }
            steps {
                script {
                    def dbProfile = params.DB_ENGINE

                    if (dbProfile == 'postgres') {
                        echo '🌱 Seeding PostgreSQL database...'

                        // Install extensions
                        sh """
                            docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T postgres-db \
                                psql -v ON_ERROR_STOP=1 -U postgres -d coc <<'EXTSQL'
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto         WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"      WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;
EXTSQL
                        """

                        // Check if DB already has data
                        def tableCount = sh(
                            script: """
                                docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T postgres-db \
                                    psql -U postgres -d coc -t -A -c \
                                    "SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema');" \
                                    | tr -d '[:space:]'
                            """,
                            returnStdout: true
                        ).trim()

                        if (tableCount == '' || tableCount == '0') {
                            echo "📥 Loading seed data from seed/dump.sql ..."
                            sh """
                                docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T postgres-db \
                                    psql -v ON_ERROR_STOP=1 -U postgres -d coc < seed/dump.sql
                            """
                            echo '✅ PostgreSQL seed complete.'
                        } else {
                            echo "⏩ Database already has ${tableCount} tables — skipping seed."
                        }

                    } else {
                        echo '🌱 Seeding MySQL database...'

                        // Generate MySQL dump if it doesn't exist
                        sh '''
                            if [ ! -f seed/dump_mysql.sql ]; then
                                echo "📝 Generating MySQL-compatible seed..."
                                chmod +x pg2mysql.sh
                                bash pg2mysql.sh
                            fi
                        '''

                        // Check if DB already has tables
                        def tableCount = sh(
                            script: """
                                docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T mysql-db \
                                    mysql -uroot -pexample -N -e \
                                    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='coc';" \
                                    2>/dev/null | tr -d '[:space:]'
                            """,
                            returnStdout: true
                        ).trim()

                        if (tableCount == '' || tableCount == '0') {
                            echo "📥 Loading MySQL seed data from seed/dump_mysql.sql ..."
                            sh """
                                docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} exec -T mysql-db \
                                    mysql -uroot -pexample coc < seed/dump_mysql.sql
                            """
                            echo '✅ MySQL seed complete.'
                        } else {
                            echo "⏩ MySQL database already has ${tableCount} tables — skipping seed."
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Stage 6: Start COC API
        // =====================================================================
        stage('Start COC API') {
            steps {
                script {
                    def dbProfile = params.DB_ENGINE
                    echo '🚀 Starting COC API...'
                    sh """
                        COMPOSE_PROFILES=${dbProfile} \
                        DATABASE_URL='${env.DATABASE_URL}' \
                        SUPABASE_URL='${params.SUPABASE_URL ?: ''}' \
                        SUPABASE_SERVICE_ROLE_KEY='${params.SUPABASE_SERVICE_ROLE_KEY ?: ''}' \
                        docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} up -d coc-api
                    """
                }
            }
        }

        // =====================================================================
        // Stage 7: Wait for API
        // =====================================================================
        stage('Wait for API Health') {
            steps {
                echo '⏳ Waiting for COC API to become healthy...'
                sh """
                    RETRIES=20
                    until curl -sf http://localhost:${env.API_PORT}/health > /dev/null 2>&1; do
                        RETRIES=\$((RETRIES - 1))
                        if [ \$RETRIES -le 0 ]; then
                            echo '⚠️  API health check timed out — checking logs...'
                            docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} logs coc-api --tail=50
                            exit 1
                        fi
                        echo "  Waiting for API... (\$RETRIES retries left)"
                        sleep 3
                    done
                    echo '✅ COC API is healthy at http://localhost:${env.API_PORT}'
                """
            }
        }

        // =====================================================================
        // Stage 8: Start Member Services
        // =====================================================================
        stage('Start Member Services') {
            steps {
                echo '🚀 Starting Member Backend + Frontend...'
                sh """
                    COMPOSE_PROFILES=${params.DB_ENGINE} \
                    DATABASE_URL='${env.DATABASE_URL}' \
                    JWT_SECRET='${params.JWT_SECRET_MEMBER}' \
                    REFRESH_SECRET='${params.REFRESH_SECRET_MEMBER}' \
                    SALTING='${params.SALTING_MEMBER}' \
                    EMAIL_ID='${params.EMAIL_ID ?: ''}' \
                    RESEND_API_KEY='${params.RESEND_API_KEY ?: ''}' \
                    GOOGLE_CLIENT_ID='${params.GOOGLE_CLIENT_ID ?: ''}' \
                    GOOGLE_CLIENT_SECRET='${params.GOOGLE_CLIENT_SECRET ?: ''}' \
                    GOOGLE_CALLBACK_URL='http://localhost:${env.MEMBER_BACKEND_PORT}/auth/google/callback' \
                    GITHUB_CLIENT_ID='${params.GITHUB_CLIENT_ID ?: ''}' \
                    GITHUB_CLIENT_SECRET='${params.GITHUB_CLIENT_SECRET ?: ''}' \
                    GITHUB_CALLBACK_URL='http://localhost:${env.MEMBER_BACKEND_PORT}/auth/github/callback' \
                    docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} up -d coc-member-backend coc-member-frontend
                """
            }
        }

        // =====================================================================
        // Stage 9: Start Admin Services
        // =====================================================================
        stage('Start Admin Services') {
            steps {
                echo '🚀 Starting Admin Backend + Frontend...'
                sh """
                    COMPOSE_PROFILES=${params.DB_ENGINE} \
                    DATABASE_URL='${env.DATABASE_URL}' \
                    JWT_SECRET='${params.JWT_SECRET_ADMIN}' \
                    REFRESH_SECRET='${params.REFRESH_SECRET_ADMIN}' \
                    SALTING='${params.SALTING_ADMIN}' \
                    EMAIL_ID='${params.EMAIL_ID ?: ''}' \
                    CONTACT_EMAIL_ID='${params.CONTACT_EMAIL_ID ?: ''}' \
                    RESEND_API_KEY='${params.RESEND_API_KEY ?: ''}' \
                    ALLOWED_ORIGINS='http://localhost:${env.ADMIN_FRONTEND_PORT}' \
                    docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} up -d coc-admin-backend coc-admin-frontend
                """
            }
        }

        // =====================================================================
        // Stage 10: Final Health Check — All Services
        // =====================================================================
        stage('Ecosystem Health Check') {
            steps {
                echo '🏥 Running final health checks on all services...'
                sh """
                    echo ''
                    echo '═══════════════════════════════════════════════════'
                    echo '  COC Ecosystem — Service Status'
                    echo '═══════════════════════════════════════════════════'

                    # API
                    if curl -sf http://localhost:${env.API_PORT}/health > /dev/null 2>&1; then
                        echo '  ✅ COC API            → http://localhost:${env.API_PORT}'
                    else
                        echo '  ❌ COC API            → UNHEALTHY'
                    fi

                    # Member Backend
                    if curl -sf http://localhost:${env.MEMBER_BACKEND_PORT}/health > /dev/null 2>&1; then
                        echo '  ✅ Member Backend     → http://localhost:${env.MEMBER_BACKEND_PORT}'
                    else
                        echo '  ❌ Member Backend     → UNHEALTHY'
                    fi

                    # Member Frontend
                    if curl -sf http://localhost:${env.MEMBER_FRONTEND_PORT} > /dev/null 2>&1; then
                        echo '  ✅ Member Frontend    → http://localhost:${env.MEMBER_FRONTEND_PORT}'
                    else
                        echo '  ⚠️  Member Frontend   → Not responding (may need browser check)'
                    fi

                    # Admin Backend
                    if curl -sf http://localhost:${env.ADMIN_BACKEND_PORT}/health > /dev/null 2>&1; then
                        echo '  ✅ Admin Backend      → http://localhost:${env.ADMIN_BACKEND_PORT}'
                    else
                        echo '  ❌ Admin Backend      → UNHEALTHY'
                    fi

                    # Admin Frontend
                    if curl -sf http://localhost:${env.ADMIN_FRONTEND_PORT} > /dev/null 2>&1; then
                        echo '  ✅ Admin Frontend     → http://localhost:${env.ADMIN_FRONTEND_PORT}'
                    else
                        echo '  ⚠️  Admin Frontend    → Not responding (may need browser check)'
                    fi

                    echo '═══════════════════════════════════════════════════'
                    echo ''
                """
            }
        }
    }

    // =========================================================================
    // Post Actions
    // =========================================================================
    post {
        success {
            echo '''
╔═══════════════════════════════════════════════════════════════╗
║  🎉 COC Ecosystem deployed successfully!                     ║
║                                                               ║
║  Services:                                                    ║
║    API:              http://localhost:3000                     ║
║    Member Frontend:  http://localhost:5174                     ║
║    Admin Frontend:   http://localhost:5173                     ║
║    Member Backend:   http://localhost:3001                     ║
║    Admin Backend:    http://localhost:8000                     ║
║                                                               ║
║  To stop: docker compose -f docker-compose.ecosystem.yml      ║
║           -p coc-ecosystem down                               ║
╚═══════════════════════════════════════════════════════════════╝
'''
        }
        failure {
            echo '❌ Pipeline failed! Cleaning up containers...'
        }
        cleanup {
            cleanWs()
        }
    }
}
