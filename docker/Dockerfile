FROM --platform=armhf debian:buster AS pisdlbuild

# build with: docker build -t pisdlbuild docker/
# run with:   docker run --platform armhf -v ${PWD}/work:/work --rm pisdlbuild > work/buildlog.txt

# this adds pi deb keys keys to system, (to allow install)
RUN apt-get update && apt-get install -y gnupg2 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 82B129927FA3303E && apt-get remove -y gnupg2

# this adds src repos, so you can do apt-get build-dep
RUN sed 's/deb /deb-src /g'  /etc/apt/sources.list > tmpsrc && cat tmpsrc >> /etc/apt/sources.list && rm tmpsrc

# This adds raspbian repos
COPY sysmods/raspi.list /etc/apt/sources.list.d/raspi.list

# add any other deps you need, here
RUN apt-get update && apt-get install -y build-essential libraspberrypi-bin libraspberrypi-dev && apt-get build-dep -y libsdl2

# download upstream source from SDL
ADD https://www.libsdl.org/release/SDL2-2.0.14.tar.gz /tmp/

# this is used because ADD doesn't let you combine URL + tar-unpacking (you have to pick 1 or other)
RUN mkdir -p /usr/src/sdl/ && tar -xvzf /tmp/SDL2-2.0.14.tar.gz -C /usr/src/sdl/ && rm /tmp/SDL2-2.0.14.tar.gz

# This adds custom debian-rules for building SDL
COPY sysmods/rules-sdl /usr/src/sdl/SDL2-2.0.14/debian/rules

# delete package cache
RUN apt-get clean

# later you can copy your  debs here
VOLUME /work

# this is the downloaded source-tree
WORKDIR /usr/src/sdl/SDL2-2.0.14

# this does the actual build on run and copies files to /work (which should be volume-mounted)
CMD cd /usr/src/sdl/SDL2-2.0.14/ && dpkg-buildpackage -us -uc -j12 && cp /usr/src/sdl/*.deb /work