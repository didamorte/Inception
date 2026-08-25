COMPOSE = docker compose -f srcs/docker-compose.yml

.PHONY: all up down clean fclean re

all: up

up:
	mkdir -p /home/diogribe/data/wordpress /home/diogribe/data/mariadb
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans

fclean: clean
	$(COMPOSE) down -v --rmi all --remove-orphans
	sudo rm -rf /home/diogribe/data

re: fclean up
