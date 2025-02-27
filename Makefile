.PHONY: default build run clean

IMAGE_NAME := trade-tariff-backend
COMMON_ENV := --env-file ".env.development" \
							-e 'SECRET_KEY_BASE=0620b2907b1cee61dbcf5cbbf4125c04bf5db3554c66589d40a9349b5abd5463a40f4a1a8c2db9b07c13715340ee3c94bbc24b1adb3140a20f702e9dc3d4fc0c' \
							-e 'GOVUK_APP_DOMAIN=localhost' \
							-e 'GOVUK_WEBSITE_ROOT=http://localhost/' \
							-e 'DATABASE_URL=postgres://${USER}:@localhost:5432/tariff_development' \
							-e 'TARIFF_FROM_EMAIL=test@localhost' \
							-e 'TARIFF_SYNC_EMAIL=test@localhost' \
							-e 'RAILS_ASSUME_SSL=false'

default: build run

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run \
		--network=host \
		--rm \
		--name $(IMAGE_NAME) \
		$(COMMON_ENV) \
		$(IMAGE_NAME)

clean:
	docker rmi $(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--name $(IMAGE_NAME)-shell \
		$(COMMON_ENV) \
		--no-healthcheck \
		-it $(IMAGE_NAME) /bin/sh
