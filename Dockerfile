# This Dockerfile extends the lscr.io/linuxserver/webtop:ubuntu-xfce image and
# adds support for PyTorch 2.6, HuggingFace Transformers, and JupyterLab.
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# Install OpenSSH server, Python and development tools.  

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        python3 \
        python3-pip \
        python3-venv \
        python3-setuptools \
        build-essential \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# Upgrade pip and configure the Jetson AI Lab index for AArch64 wheels.  The
# pypi.jetson-ai-lab.io server hosts NVIDIA‑built wheels for PyTorch and
# related libraries on Jetson.  

RUN python3 -m pip install --upgrade pip \
    && pip3 config set global.extra-index-url https://pypi.jetson-ai-lab.io/simple \
    && pip3 config set global.trusted-host pypi.jetson-ai-lab.io

# Install PyTorch 2.6, torchvision and torchaudio.

RUN pip3 install --no-cache-dir \
        torch==2.6.0 \
        torchvision==0.17.0 \
        torchaudio==2.6.0 \
    && pip3 install --no-cache-dir \
        accelerate \
        sentencepiece \
        optimum \
    && pip3 install --no-cache-dir transformers \
    && pip3 install --no-cache-dir jupyterlab notebook


COPY custom-cont-init.d/ /custom-cont-init.d/
COPY custom-services.d/ /custom-services.d/
RUN chmod +x /custom-cont-init.d/* /custom-services.d/*

# Expose SSH and JupyterLab ports.  The SSH service continues to listen on
# port 22, and JupyterLab listens on port 8888 when started via a service.
EXPOSE 22 8888

