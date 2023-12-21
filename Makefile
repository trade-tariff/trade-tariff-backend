.PHONY: all build run clean

IMAGE_NAME := trade-tariff-backend

all: build

build:
	docker build --build-arg DATABASE_USER=$(USER) -t $(IMAGE_NAME) .

run:
	# if $(uname -a | grep -q Darwin); then \
		# docker run --env-file ".env.development" -P $(IMAGE_NAME)
	# # else \
		docker run --env-file ".env.development" --network=host $(IMAGE_NAME)
	# fi

clean:
	docker rmi $(IMAGE_NAME)
