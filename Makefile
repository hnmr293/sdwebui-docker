all: Dockerfile
	sudo DOCKER_BUILDKIT=1 docker image build -t hnmr293/sdwebui .

