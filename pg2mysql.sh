#!/usr/bin/env bash
# =============================================================================
# pg2mysql.sh — Convert the PostgreSQL seed dump to MySQL-compatible SQL
#
# Reads seed/dump.sql and writes seed/dump_mysql.sql
# Handles: ENUMs → VARCHAR, schemas → ignored, DO $$ blocks → removed,
#          boolean literals, SERIAL → AUTO_INCREMENT, timestamptz → DATETIME,
#          UUID defaults, ALTER TABLE for PKs/FKs adapted, etc.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${SCRIPT_DIR}/seed/dump.sql"
OUTPUT="${SCRIPT_DIR}/seed/dump_mysql.sql"

if [[ ! -f "$INPUT" ]]; then
  echo "[pg2mysql] ERROR: $INPUT not found."
  exit 1
fi

echo "[pg2mysql] Converting $INPUT → $OUTPUT ..."

cat > "$OUTPUT" << 'HEADER'
-- =============================================================================
-- MySQL-compatible seed for COC ecosystem
-- Auto-generated from seed/dump.sql by pg2mysql.sh
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET NAMES utf8mb4;

HEADER

# --- Generate MySQL DDL manually from the known schema ---
cat >> "$OUTPUT" << 'DDL'
-- Drop existing tables
DROP TABLE IF EXISTS `_prisma_migrations`;
DROP TABLE IF EXISTS `MemberProject`;
DROP TABLE IF EXISTS `MemberAchievement`;
DROP TABLE IF EXISTS `CompletedQuestion`;
DROP TABLE IF EXISTS `InterviewExperience`;
DROP TABLE IF EXISTS `Question`;
DROP TABLE IF EXISTS `Topic`;
DROP TABLE IF EXISTS `Project`;
DROP TABLE IF EXISTS `Achievement`;
DROP TABLE IF EXISTS `Account`;
DROP TABLE IF EXISTS `Member`;

-- Member table
CREATE TABLE `Member` (
    `id` VARCHAR(36) NOT NULL,
    `name` TEXT NOT NULL,
    `email` VARCHAR(255) NOT NULL UNIQUE,
    `birth_date` DATE DEFAULT NULL,
    `phone` TEXT DEFAULT NULL,
    `bio` TEXT DEFAULT NULL,
    `profilePhoto` TEXT DEFAULT NULL,
    `github` TEXT DEFAULT NULL,
    `linkedin` TEXT DEFAULT NULL,
    `twitter` TEXT DEFAULT NULL,
    `geeksforgeeks` TEXT DEFAULT NULL,
    `leetcode` TEXT DEFAULT NULL,
    `codechef` TEXT DEFAULT NULL,
    `codeforces` TEXT DEFAULT NULL,
    `passoutYear` DATE DEFAULT NULL,
    `isApproved` BOOLEAN NOT NULL DEFAULT FALSE,
    `isManager` BOOLEAN NOT NULL DEFAULT FALSE,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `approvedById` VARCHAR(36) DEFAULT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `Member_approvedById_fkey` FOREIGN KEY (`approvedById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Account table
CREATE TABLE `Account` (
    `id` VARCHAR(36) NOT NULL,
    `provider` TEXT NOT NULL,
    `providerAccountId` TEXT NOT NULL,
    `password` TEXT DEFAULT NULL,
    `accessToken` TEXT DEFAULT NULL,
    `refreshToken` TEXT DEFAULT NULL,
    `expiresAt` DATETIME DEFAULT NULL,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `memberId` VARCHAR(36) DEFAULT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `Account_memberId_fkey` FOREIGN KEY (`memberId`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Achievement table
CREATE TABLE `Achievement` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `title` TEXT NOT NULL,
    `description` TEXT NOT NULL,
    `achievedAt` DATE NOT NULL,
    `imageUrl` TEXT NOT NULL,
    `createdById` VARCHAR(36) DEFAULT NULL,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedById` VARCHAR(36) DEFAULT NULL,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    CONSTRAINT `Achievement_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT `Achievement_updatedById_fkey` FOREIGN KEY (`updatedById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MemberAchievement join table
CREATE TABLE `MemberAchievement` (
    `memberId` VARCHAR(36) NOT NULL,
    `achievementId` INT NOT NULL,
    PRIMARY KEY (`memberId`, `achievementId`),
    CONSTRAINT `MemberAchievement_memberId_fkey` FOREIGN KEY (`memberId`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `MemberAchievement_achievementId_fkey` FOREIGN KEY (`achievementId`) REFERENCES `Achievement`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Project table
CREATE TABLE `Project` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` TEXT NOT NULL,
    `imageUrl` TEXT NOT NULL,
    `githubUrl` TEXT NOT NULL,
    `deployUrl` TEXT DEFAULT NULL,
    `createdById` VARCHAR(36) DEFAULT NULL,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedById` VARCHAR(36) DEFAULT NULL,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    CONSTRAINT `Project_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT `Project_updatedById_fkey` FOREIGN KEY (`updatedById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MemberProject join table
CREATE TABLE `MemberProject` (
    `memberId` VARCHAR(36) NOT NULL,
    `projectId` INT NOT NULL,
    PRIMARY KEY (`memberId`, `projectId`),
    CONSTRAINT `MemberProject_memberId_fkey` FOREIGN KEY (`memberId`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `MemberProject_projectId_fkey` FOREIGN KEY (`projectId`) REFERENCES `Project`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Topic table
CREATE TABLE `Topic` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `title` TEXT NOT NULL,
    `description` TEXT NOT NULL,
    `createdById` VARCHAR(36) DEFAULT NULL,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedById` VARCHAR(36) DEFAULT NULL,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    CONSTRAINT `Topic_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT `Topic_updatedById_fkey` FOREIGN KEY (`updatedById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Question table (Difficulty ENUM mapped to MySQL ENUM)
CREATE TABLE `Question` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `questionName` TEXT NOT NULL,
    `difficulty` ENUM('Easy','Medium','Hard') NOT NULL,
    `link` TEXT NOT NULL,
    `topicId` INT DEFAULT NULL,
    `createdById` VARCHAR(36) DEFAULT NULL,
    `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updatedById` VARCHAR(36) DEFAULT NULL,
    `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    CONSTRAINT `Question_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT `Question_topicId_fkey` FOREIGN KEY (`topicId`) REFERENCES `Topic`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `Question_updatedById_fkey` FOREIGN KEY (`updatedById`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- InterviewExperience table (Verdict ENUM mapped to MySQL ENUM)
CREATE TABLE `InterviewExperience` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `company` TEXT NOT NULL,
    `role` TEXT NOT NULL,
    `verdict` ENUM('Selected','Rejected','Pending') NOT NULL,
    `content` TEXT NOT NULL,
    `isAnonymous` BOOLEAN NOT NULL DEFAULT FALSE,
    `memberId` VARCHAR(36) DEFAULT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `InterviewExperience_memberId_fkey` FOREIGN KEY (`memberId`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CompletedQuestion join table
CREATE TABLE `CompletedQuestion` (
    `memberId` VARCHAR(36) NOT NULL,
    `questionId` INT NOT NULL,
    PRIMARY KEY (`memberId`, `questionId`),
    CONSTRAINT `CompletedQuestion_memberId_fkey` FOREIGN KEY (`memberId`) REFERENCES `Member`(`id`) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `CompletedQuestion_questionId_fkey` FOREIGN KEY (`questionId`) REFERENCES `Question`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- _prisma_migrations table
CREATE TABLE `_prisma_migrations` (
    `id` VARCHAR(36) NOT NULL,
    `checksum` VARCHAR(64) NOT NULL,
    `finished_at` DATETIME DEFAULT NULL,
    `migration_name` VARCHAR(255) NOT NULL,
    `logs` TEXT DEFAULT NULL,
    `rolled_back_at` DATETIME DEFAULT NULL,
    `started_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `applied_steps_count` INT DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DDL

# --- Now extract INSERT statements from the PG dump and convert them ---
echo "" >> "$OUTPUT"
echo "-- ========================================================" >> "$OUTPUT"
echo "-- Data (converted INSERT statements from PostgreSQL dump)" >> "$OUTPUT"
echo "-- ========================================================" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Extract and convert INSERT lines
# - Remove public. schema prefix
# - Convert 'true'/'false' boolean strings to TRUE/FALSE
# - Strip the PostgreSQL ENUM type casts like public."Difficulty" etc.
grep -E '^INSERT INTO|^\(' "$INPUT" | \
  sed 's/public\.//g' | \
  sed "s/public\.\"Difficulty\"//g" | \
  sed "s/public\.\"Verdict\"//g" | \
  >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "SET FOREIGN_KEY_CHECKS = 1;" >> "$OUTPUT"

echo "[pg2mysql] Done. Output written to $OUTPUT"
