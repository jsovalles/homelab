docker_compose:
	docker compose up -d

.PHONY: backup_config
backup_config:
	@echo "Enter the password to encrypt the config backup:"
	@bash -c 'read -s PASSWORD && echo "Compressing and encrypting config directory..." && \
	tar -czf - config | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass pass:"$$PASSWORD" -out config.tar.gz.enc'
.PHONY: uncompress_config
uncompress_config:
	@echo "Enter the password to decrypt the config backup:"
	@bash -c 'read -s PASSWORD && echo "Decrypting and uncompressing config backup..." && \
	openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -pass pass:"$$PASSWORD" -in config.tar.gz.enc -out - | tar -xzf -'

remove_unused_images:
	docker image prune -f -a
