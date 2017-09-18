FROM debian:stretch

MAINTAINER Jochen Saalfeld "jochen@intevation.de"


RUN 	apt-get update && \
	apt-get install -y curl gnupg && \ 
	curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
	apt-get update && \
	apt-get install -y build-essential git autoconf automake zip perl npm nodejs \
		python && \
	npm install -g eslint

CMD 	usr=$(stat -c "%u" /build) && \
	grp=$(stat -c "%g" /build) && \
	ls -lA / && ls -lA build && \
	cd /build/enigmail && \
	./configure && \
	make && \
	make test && \
	chown -R $usr:$grp /build
