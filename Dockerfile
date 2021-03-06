FROM debian:stretch-slim
RUN set -x &&\
	apt-get update &&\
	apt-get install --no-install-recommends --no-install-suggests -y \
		git ca-certificates autoconf build-essential\
		libreadline-dev libssl-dev &&\
	git clone https://github.com/findstr/RssReader.git &&\
	cd RssReader && git submodule update --init &&\
	cd zlib && CFLAGS='-mstackrealign -fPIC -O3' ./configure &&\
	cd ../silly && patch -p1 < ssl.patch && make &&\
	cd ../ && make &&\
	rm -rf silly/deps &&\
	apt-get remove --purge --auto-remove -y git ca-certificates build-essential autoconf libreadline-dev &&\
	rm -rf /var/lib/apt/lists/*

WORKDIR /RssReader
#ENTRYPOINT ["/bin/sh"]
CMD ["./silly/silly", "server/rssd.conf"]"

