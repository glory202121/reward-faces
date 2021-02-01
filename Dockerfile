# set the base image
FROM tensorflow/tensorflow:2.4.1

RUN echo 'Starting Docker build'

# update sources list install dependencies
RUN echo 'Installing dependencies'
RUN apt-get update
RUN apt-get install -y sudo
RUN apt-get install -y build-essential \
					   cmake \
					   pkg-config \
					   unzip \
					   yasm \
					   git \
					   wget \
					   checkinstall
RUN apt-get install -y libjpeg-dev \
					   libpng-dev \
					   libtiff-dev
RUN apt-get install -y libavcodec-dev \
					   libavformat-dev \
					   libswscale-dev \
					   libavresample-dev
RUN apt-get install -y flex \
					   bison
RUN apt-get install -y libxvidcore-dev \
					   libx264-dev \
					   libfaac-dev \
					   libmp3lame-dev \
					   libtheora-dev \
					   libvorbis-dev \
					   libdc1394-22 \
					   libdc1394-22-dev \
					   libxine2-dev \
					   libv4l-dev \
					   v4l-utils \
					   libgtk-3-dev \
					   libtbb-dev \
					   libatlas-base-dev \
					   libprotobuf-dev \
					   protobuf-compiler \
					   libgoogle-glog-dev \
					   libgflags-dev \
					   libgphoto2-dev \
					   libeigen3-dev \
					   libhdf5-dev \
					   doxygen \
					   x264 \
					   libx264-dev \
					   libavfilter-dev
RUN apt-get install -y pkgconf
RUN apt-get install -y ninja-build

RUN echo 'Upgrading pip'
RUN python3 -m pip install --upgrade pip

# creating user and directory structure
RUN echo 'Creating user directory'
RUN mkdir -p /home/crc/
RUN groupadd -r crc && useradd --no-log-init -r -d /home/crc/ -g crc crc && adduser crc sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN chown crc:crc /home/crc

USER crc

# install meson
RUN echo 'Installing meson'
WORKDIR /home/crc/
RUN sudo python3 -m pip uninstall -y typing
RUN python3 -m pip install meson
ENV PATH="~/.local/bin:${PATH}"

# install nvcodec
RUN echo "Installing nvcodec"
WORKDIR /home/crc/
RUN git clone https://github.com/FFmpeg/nv-codec-headers.git
RUN cd nv-codec-headers && make && sudo make install

# install gstreamer
RUN echo "Installing gstreamer"
WORKDIR /home/crc/
RUN git clone https://gitlab.freedesktop.org/gstreamer/gst-build
RUN cd gst-build
RUN python3 gst-worktree.py add gst-build-1.18 origin/1.18
RUN cd gst-build-1.18/ && ~/.local/bin/meson build && ~/.local/bin/meson configure build/ -Dgst-plugins-bad:nvcodec=enabled;

RUN sudo ninja -C build install

# ENV GST_PLUGIN_PATH="/usr/local/lib/x86_64-linux-gnu/gstreamer-1.0/:${GST_PLUGIN_PATH}"

# install opencv
RUN echo 'Installing OpenCV'
WORKDIR /home/crc/
RUN wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.1.0.zip
RUN unzip opencv_contrib.zip
RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/4.1.0.zip
RUN unzip opencv.zip
RUN cd opencv-4.1.0/
RUN mkdir build/
RUN cd build/
RUN cmake -D CMAKE_BUILD_TYPE=RELEASE \
-D INSTALL_PYTHON_EXAMPLES=OFF \
-D INSTALL_C_EXAMPLES=OFF \
-D PYTHON_EXECUTABLE=$(which python3) \
-D BUILD_opencv_python2=OFF \
-D CMAKE_INSTALL_PREFIX=$(python3 -c "import sys; print(sys.prefix)") \
-D PYTHON3_EXECUTABLE=$(which python3) \
-D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
-D PYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
-D WITH_TBB=ON \
-D WITH_GSTREAMER=ON \
-D ENABLE_FAST_MATH=1 \
-D WITH_V4L=ON \
-D WITH_QT=OFF \
-D OPENCV_GENERATE_PKGCONFIG=ON \
-D OPENCV_PC_FILE_NAME=opencv.pc \
-D OPENCV_ENABLE_NONFREE=ON \
-D WITH_OPENGL=ON \
-D BUILD_DOCS=OFF \
-D BUILD_PERF_TESTS=OFF \
-D BUILD_TESTS=OFF \
-D BUILD_EXAMPLES=OFF \
-D CMAKE_CXX_FLAGS=-fpermissive \
-D WITH_FFMPEG=0 opencv-4.1.0/ \
&& sudo make -j$(nproc) install \
&& sudo ldconfig

# copy project into docker
RUN echo 'Creating and Copy project into Docker'
WORKDIR /home/crc
RUN mkdir -p reward-faces
RUN cd reward-faces
COPY ./ ./

# install python requirements
RUN echo 'Installing requirements'
RUN python3 -m pip install --user -r docker-requirements.txt

RUN echo 'Docker build complete'

# set environment variable
ENV LIBGL_ALWAYS_INDIRECT=1
CMD python3 -u process.py
