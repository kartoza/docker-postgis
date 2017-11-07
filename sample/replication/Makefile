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
