FROM --platform=armhf debian:buster AS pilovebuild

# build with: docker build -f docker/love.Dockerfile -t pilovebuild docker/
# run with:   docker run --platform armhf -v ${PWD}/work:/work --rm pilovebuild

# this adds pi deb keys keys to system, (to allow install)
RUN apt-get update && apt-get install -y gnupg2 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 82B129927FA3303E && apt-get remove -y gnupg2

# this adds src repos, so you can do apt-get build-dep
RUN sed 's/deb /deb-src /g'  /etc/apt/sources.list > tmpsrc && cat tmpsrc >> /etc/apt/sources.list && rm tmpsrc

# This adds raspbian repos
COPY sysmods/raspi.list /etc/apt/sources.list.d/raspi.list

# add any other deps you need, here
RUN apt-get update && \
  apt-get install -y git build-essential libraspberrypi-bin libraspberrypi-dev debhelper dh-autoreconf \
  pkg-config libtool g++ libfreetype6-dev luajit libluajit-5.1-dev libmodplug-dev libmpg123-dev libopenal-dev \
  libphysfs-dev libsdl2-dev libogg-dev libvorbis-dev libtheora-dev zlib1g-dev && apt-get build-dep -y libsdl2

# download upstream source from love
RUN git clone --depth=1 https://github.com/love2d/love /usr/src/love && cd /usr/src/love && apt-get remove -y git

# download our built debs for SDL
RUN apt-get install -y wget && \
  wget https://github.com/notnullgames/nullos2/releases/download/initial/libsdl2-dev_2.0.14_armhf.deb -O /tmp/libsdl2-dev_2.0.14_armhf.deb && \
  wget https://github.com/notnullgames/nullos2/releases/download/initial/libsdl2_2.0.14_armhf.deb -O /tmp/libsdl2_2.0.14_armhf.deb && \
  apt-get install -y /tmp/libsdl2*.deb && \
  rm -f /tmp/libsdl2*.deb && \
  apt-get remove -f wget

# delete package cache
RUN apt-get clean

# later you can copy your  debs here
VOLUME /work

# this is the downloaded source-tree
WORKDIR /usr/src/love

# this does the actual build on run and copies files to /work (which should be volume-mounted)
CMD cd /usr/src/love && ./platform/unix/automagic | tee /work/buildlog-love.txt && ./configure | tee -a /work/buildlog-love.txt && \
  cp -R platform/unix/debian/ . && dpkg-buildpackage -us -uc -j12 | tee -a /work/buildlog-love.txt && cp /usr/src/*.deb /work