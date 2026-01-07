NAME = inception

DOCKER = cd srcs && docker compose -f docker-compose.yml

all: up

up:
	mkdir -p /home/sdemiroz/data/db
	mkdir -p /home/sdemiroz/data/wp

	$(DOCKER) up -d --build

down:
	$(DOCKER) down

clean:
	$(DOCKER) down -v

fclean: clean
	sudo rm -rf /home/sdemiroz/data/db
	sudo rm -rf /home/sdemiroz/data/wp
	docker system prune -af --volumes

re: fclean up

.PHONY: all up down clean fclean re
