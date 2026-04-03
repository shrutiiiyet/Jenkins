# Jenkins (Docker)

Lightweight repository containing a Dockerfile and supporting files for running Jenkins in a containerized environment.

**Contents**
- `Dockerfile` — build instructions for the Jenkins image in this repo.
- `secret-file` — contains sensitive information. Do not commit secrets to public repos.

**Prerequisites**
- Docker (tested on Docker Engine 20.10+)

**Quick start**

1. Create a bridge network in docker

```bash
docker network create jenkins
```

1. Build the Jenkins master node:

```bash
docker build -t jenkins-custom:latest .
```

3. Run the container:

```bash
docker run -d --name jenkins \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  jenkins-custom:latest
```

3. Access Jenkins at: `http://localhost:8080`

To create agents for the master node
```bash
docker run -d --rm --name=agent1 -p 22:22 -e "JENKINS_AGENT_SSH_PUBKEY=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJKWBfo57hf1XOUkS9B/bU4BejHUe8c2yLI/c+29ipA" jenkins/ssh-agent:alpine-jdk21
```


**Notes**
- This repo provides a minimal Docker-based Jenkins setup. You may want to replace or extend the Dockerfile to use the official `jenkins/jenkins` image, install plugins, or provision jobs/config as code.
