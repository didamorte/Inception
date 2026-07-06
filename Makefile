COMPOSE = docker compose -f srcs/docker-compose.yml

.PHONY: all up down clean fclean re

all: up

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans

fclean: clean
	$(COMPOSE) down -v --rmi all --remove-orphans

re: fclean up
