all: Dockerfile
	sudo docker image build -t hnmr293/sdwebui:v0.1 .
