FROM debian:buster as build

ENV DEBIAN_FRONTEND=noninteractive

# working dir
WORKDIR /opt

# install dependencies
RUN set -xe \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        extlinux syslinux-efi syslinux-common gdisk dosfstools tree \
    && mkdir -p /opt/conf /opt/img 

# copy files
COPY entrypoint.sh /entrypoint.sh
COPY syslinux/ /opt/conf
COPY image/ /opt/img

# start bash
ENTRYPOINT [ "/bin/bash" , "-c"]
CMD [ "/entrypoint.sh" ]