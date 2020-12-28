SHELL=/bin/bash


export DATAPREP_VERSION := $(shell cat projects/deaths/recipes/dataprep_deaths.yml | sha1sum | awk '{print $1}' | cut -c-8)
export PWD := $(shell pwd)
export APP_PATH=${PWD}
export GIT = $(shell which git)
export GITROOT = https://github.com/matchid-project
export GIT_BACKEND = backend
export ES_NODES=1
export ES_MEM=1024m
export ES_PRELOAD=[]
export ES_THREADS = 2

export RECIPE = dataprep_deaths
export RECIPE_THREADS = 2
export RECIPE_QUEUE = 1

export DATA_TAG=deaths # TODO: set data-tag
export BACKUP_DIR = ${PWD}/${GIT_BACKEND}/backup

dummy               := $(shell touch artifacts)
include ./artifacts

${GIT_BACKEND}:
	@echo configuring matchID
	@${GIT} clone -q ${GITROOT}/${GIT_BACKEND}
	@cp artifacts ${GIT_BACKEND}/artifacts
	@cp docker-compose-local.yml ${GIT_BACKEND}/docker-compose-local.yml
	@echo "export ES_NODES=${ES_NODES}" >> ${GIT_BACKEND}/artifacts
	@echo "export PROJECTS=${PWD}/projects" >> ${GIT_BACKEND}/artifacts
	@sed -i -E "s/backend: network backend-docker-check/backend: network #backend-docker-check/"  backend/Makefile
	@sed -i -E "s/export API_SECRET_KEY:=(.*)/export API_SECRET_KEY:=1234/"  backend/Makefile
	@sed -i -E "s/export ADMIN_PASSWORD:=(.*)/export ADMIN_PASSWORD:=1234ABC/"  backend/Makefile
	@sed -i -E "s/id(.*):=(.*)/id:=myid/"  backend/Makefile

backup-dir:
	mkdir -p ${BACKUP_DIR}

config: ${GIT_BACKEND}
	@echo checking system prerequisites
	@${MAKE} -C ${APP_PATH}/${GIT_BACKEND} config && \
	echo "prerequisites installed" > config

recipe-run:
	@if [ ! -f recipe-run ];then\
		${MAKE} -C ${APP_PATH}/${GIT_BACKEND} elasticsearch ES_NODES=${ES_NODES} ES_MEM=${ES_MEM} ${MAKEOVERRIDES};\
		echo running recipe on full data;\
		${MAKE} -C ${APP_PATH}/${GIT_BACKEND} recipe-run \
			RECIPE=${RECIPE} RECIPE_THREADS=${RECIPE_THREADS} RECIPE_QUEUE=${RECIPE_QUEUE}\
			ES_PRELOAD='${ES_PRELOAD}' ES_THREADS=${ES_THREADS} \
			${MAKEOVERRIDES} \
			APP=backend APP_VERSION=$(shell cd ${APP_PATH}/${GIT_BACKEND} && make version | awk '{print $$NF}') \
			&&\
		touch recipe-run &&\
		(echo esdata_${DATAPREP_VERSION}_${DATA_TAG}.tar > elasticsearch-restore);\
	fi

watch-run:
	@LOG_FILE=$(shell find ${GIT_BACKEND}/log/ -iname '*${RECIPE}*' | sort | tail -1);\
	timeout=${TIMEOUT} ; ret=1 ; \
		until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do \
			((tail $$LOG_FILE | grep "end of all" > /dev/null) || exit 1) ; \
			ret=$$? ; \
			if [ "$$ret" -ne "0" ] ; then \
				grep inserted $$LOG_FILE |awk 'BEGIN{s=0}{t=$$4;s+=$$14}END{printf("\rwrote %d in %s",s,t)}' ;\
				grep -i Ooops $$LOG_FILE | wc -l | awk '($$1>${ERR_MAX}){exit 1}' || exit 0;\
				sleep 10 ;\
			fi ; ((timeout--)); done ;
	@LOG_FILE=$(shell find ${GIT_BACKEND}/log/ -iname '*${RECIPE}*' | sort | tail -1);\
	((egrep -i 'end : run|Ooops' $$LOG_FILE | tail -5) && exit 1) || \
	egrep 'end : run.*successfully' $$LOG_FILE

backup: backup-dir
	@if [ ! -f backup ];then\
		ES_BACKUP_FILE=esdata_${DATAPREP_VERSION}_${DATA_TAG}.tar;\
		ES_BACKUP_FILE_SNAR=esdata_${DATAPREP_VERSION}_$$(cat ${DATA_TAG}).snar;\
		if [ ! -f "${BACKUP_DIR}/$$ES_BACKUP_FILE" ];then\
			${MAKE} -C ${APP_PATH}/${GIT_BACKEND} elasticsearch-backup \
				ES_BACKUP_FILE=$$ES_BACKUP_FILE\
				ES_BACKUP_FILE_SNAR=$$ES_BACKUP_FILE_SNAR;\
		fi;\
		touch backup;\
	fi

