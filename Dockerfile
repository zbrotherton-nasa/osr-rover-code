FROM ros:jazzy
ARG USERNAME=USERNAME
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV ROS_DOMAIN_ID=42

SHELL ["/bin/bash", "-c"]

# Delete user if it exists in container (e.g Ubuntu Noble: ubuntu)
RUN if id -u $USER_UID ; then userdel `id -un $USER_UID` ; fi

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y python3 python3-pip
# Install demo packages
RUN apt-get install -y \
      ros-${ROS_DISTRO}-demo-nodes-cpp \
      ros-${ROS_DISTRO}-demo-nodes-py && \
    rm -rf /var/lib/apt/lists/*
# Prepare for x11 forwarding - verifiy necessary
RUN apt-get update && \
    apt-get install -y x11-apps
ENV DISPLAY=:0
# Set environment variables so gazebo can utilize discrete GPU
ENV MESA_GL_VERSION_OVERRIDE=4.5
ENV __NV_PRIME_RENDER_OFFLOAD=1
ENV __GLX_VENDOR_LIBRARY_NAME=nvidia
# Add code to image
ADD . /osr-ws/src
# Configure rosdep
RUN apt-get update \
    && rosdep update --rosdistro ${ROS_DISTRO} \
    && rosdep install -y --from-paths /osr-ws --ignore-src --rosdistro=${ROS_DISTRO}
# Install additional OSR dependencies and build
RUN python3 -m pip install --break-system-packages adafruit-circuitpython-servokit ina260 RPi.GPIO smbus
WORKDIR /osr-ws
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && colcon build --symlink-install
WORKDIR /
# Source ROS on terminal start
RUN echo "source /osr-ws/install/setup.bash" >> ~/.bashrc
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc

CMD [ "bash" ]