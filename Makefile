SHELL=/bin/bash

export PWD := $(shell pwd)
export APP_PATH=${PWD}
export GIT = $(shell which git)
export GITROOT = https://github.com/matchid-project
export GIT_BACKEND = backend
export ES_NODES=1

dummy               := $(shell touch artifacts)
include ./artifacts

${GIT_BACKEND}:
	@echo configuring matchID
	@${GIT} clone -q ${GITROOT}/${GIT_BACKEND}
	@cp artifacts ${GIT_BACKEND}/artifacts
	@cp docker-compose-local.yml ${GIT_BACKEND}/docker-compose-local.yml
	@echo "export ES_NODES=${ES_NODES}" >> ${GIT_BACKEND}/artifacts
	@echo "export PROJECTS=${PWD}/projects" >> ${GIT_BACKEND}/artifacts
	@sed -i -E "s/urandom/random/"  backend/Makefile

config: ${GIT_BACKEND}
	@echo checking system prerequisites
	@${MAKE} -C ${APP_PATH}/${GIT_BACKEND} config && \
	echo "prerequisites installed" > config

