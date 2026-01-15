NAME = inception

include srcs/.env

DOCKER = docker compose -f srcs/docker-compose.yml
SECRETS_DIR = $(CURDIR)/secrets
REQUIRED_SECRETS = \
	$(SECRETS_DIR)/db_root_password.txt \
	$(SECRETS_DIR)/db_password.txt \
	$(SECRETS_DIR)/wp_admin_password.txt \
	$(SECRETS_DIR)/wp_user_password.txt

all: up

secrets:
	@for f in $(REQUIRED_SECRETS); do \
		if [ ! -f "$$f" ]; then \
			echo "Missing secret: $$f"; \
			echo "Create secrets with: bash scripts/init_secrets.sh"; \
			exit 1; \
		fi; \
	done

up: secrets
	mkdir -p $(DATA_PATH)/db
	mkdir -p $(DATA_PATH)/wp

	$(DOCKER) up -d --build

down:
	$(DOCKER) down

clean:
	$(DOCKER) down -v

fclean: clean
	sudo rm -rf $(DATA_PATH)/db
	sudo rm -rf $(DATA_PATH)/wp
	docker system prune -af --volumes

re: fclean up

.PHONY: all secrets up down clean fclean re
