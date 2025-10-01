# A custom Dockerfile for a persistent Webtop environment on Jetson Orin Nano
#
# This image is built on top of the LinuxServer.io Webtop image (Ubuntu XFCE
# edition).  The base Webtop image provides a full desktop session in a web
# browser.  This Dockerfile extends the image by installing an OpenSSH server
# into the container so that you can connect to it over the network with
# SSH.  It also integrates the LinuxServer.io custom init and service
# mechanisms, allowing the SSH daemon to start automatically whenever the
# container boots.  The installation of OpenSSH happens at build time so
# that the package is included in the final image and does not have to be
# re‑installed each time the container is recreated.

FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# Install OpenSSH server.  The `--no-install-recommends` flag avoids pulling in
# unnecessary packages.  We remove the apt cache afterwards to keep the
# resulting image small.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# Copy custom init scripts and service definitions.  These files live in the
# special directories `/custom-cont-init.d` and `/custom-services.d` which are
# processed by the S6 init system used in LinuxServer containers.  See
# https://docs.linuxserver.io/general/container-customization/ for details on
# how these hooks work【382432676714424†L363-L370】.
COPY custom-cont-init.d/ /custom-cont-init.d/
COPY custom-services.d/ /custom-services.d/
RUN chmod +x /custom-cont-init.d/* /custom-services.d/*

# Expose the SSH port.  Webtop exposes its own ports for the web desktop; we
# explicitly expose port 22 here for clarity.  The actual mapping of this
# port is configured in the docker-compose file or run command.
EXPOSE 22

# End of Dockerfile