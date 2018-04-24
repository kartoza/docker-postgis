up:
	docker-compose up -d

down:
	docker-compose down

scale:
	docker-compose up -d --scale pg-slave=3

unscale:
	docker-compose up -d --scale pg-slave=1

status:
	docker-compose ps

master-shell:
	docker-compose exec pg-master /bin/bash

slave-shell:
	docker-compose exec pg-slave /bin/bash

master-log:
	docker-compose logs -f --tail=30 pg-master

slave-log:
	docker-compose logs -f --tail=30 pg-slave


# These commands were used for travis

master-log-tail	:
	docker-compose logs --tail=30 pg-master

slave-log-tail:
	docker-compose logs --tail=30 pg-slave

check-master-running:
	@echo "Check master is running"
	@docker-compose logs --tail=1 pg-master | grep 'database system is ready to accept connections' &> /dev/null

check-master-replication:
	@docker-compose exec pg-master /bin/sh -c "su - postgres -c \"/tests/replication_test_master.sh\""

check-slave-running:
	@echo "Check slave is running"
	@docker-compose logs pg-slave | grep 'database system is ready to accept read only connections' &> /dev/null
	@docker-compose logs pg-slave | grep 'started streaming WAL from primary' &> /dev/null

check-slave-replication:
	@docker-compose exec pg-slave /bin/sh -c "su - postgres -c \"/tests/replication_test_slave.sh\""
