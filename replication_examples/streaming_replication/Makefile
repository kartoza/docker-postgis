up:
	docker-compose up -d

down:
	docker-compose down

scale:
	docker-compose up -d --scale pg-node=3

unscale:
	docker-compose up -d --scale pg-node=1

status:
	docker-compose ps

master-shell:
	docker-compose exec pg-master /bin/bash

node-shell:
	docker-compose exec pg-node /bin/bash

master-log:
	docker-compose logs -f --tail=30 pg-master

node-log:
	docker-compose logs -f --tail=30 pg-node

