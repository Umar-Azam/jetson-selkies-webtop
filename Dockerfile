# syntax=docker/dockerfile:1.4

# Stage 1 gathers the Jetson-optimized torch/vision/audio stack from l4t-pytorch
# so it can be reused inside the LinuxServer Webtop environment.
ARG L4T_PYTORCH_TAG=r36.4.0
FROM dustynv/l4t-pytorch:${L4T_PYTORCH_TAG} AS torch-builder

# Persist the site-packages directories that contain the prebuilt Jetson wheels.
RUN python3 - <<'PY' > /opt/pytorch-site-packages.txt
import site
paths = []
for entry in site.getsitepackages():
    if entry not in paths:
        paths.append(entry)
for entry in paths:
    print(entry)
PY

RUN tar -czf /opt/pytorch-site-packages.tgz -T /opt/pytorch-site-packages.txt

# Snapshot the Python 3.10 runtime so the final image can use the same ABI.
RUN mkdir -p /opt/python-runtime/usr/bin \
    && mkdir -p /opt/python-runtime/usr/local/bin \
    && mkdir -p /opt/python-runtime/usr/lib \
    && mkdir -p /opt/python-runtime/usr/local/lib/python3 \
    && mkdir -p /opt/python-runtime/usr/include \
    && mkdir -p /opt/python-runtime/usr/lib/aarch64-linux-gnu \
    && cp -a /usr/bin/python3.10 /opt/python-runtime/usr/bin/python3.10 \
    && cp -a /usr/bin/python3.10-config /opt/python-runtime/usr/bin/python3.10-config \
    && cp -a /usr/local/bin/pip /opt/python-runtime/usr/local/bin/pip \
    && cp -a /usr/local/bin/pip3 /opt/python-runtime/usr/local/bin/pip3 \
    && cp -a /usr/local/bin/pip3.10 /opt/python-runtime/usr/local/bin/pip3.10 \
    && cp -a /usr/lib/python3.10 /opt/python-runtime/usr/lib/python3.10 \
    && cp -a /usr/include/python3.10 /opt/python-runtime/usr/include/python3.10 \
    && cp -a /usr/local/lib/python3.10 /opt/python-runtime/usr/local/lib/python3.10 \
    && cp -a /usr/lib/aarch64-linux-gnu/libpython3.10.so* /opt/python-runtime/usr/lib/aarch64-linux-gnu/ \
    && tar -czf /opt/python310-runtime.tgz -C /opt/python-runtime .

# Archive the CUDA runtime libraries and loader configuration needed by the
# Jetson build of PyTorch so we don't rely solely on host mounts.
RUN tar -czf /opt/cuda-runtime.tgz \
        /usr/local/cuda/targets/aarch64-linux/lib \
        /usr/local/cuda/lib64 \
        /usr/lib/aarch64-linux-gnu/libcudnn* \
        /usr/lib/aarch64-linux-gnu/libnv* \
        /etc/ld.so.conf.d/000_cuda.conf \
        /etc/ld.so.conf.d/988_cuda-12.conf \
        /etc/ld.so.conf.d/gds-12-6.conf

# Record package metadata for validation/debugging purposes.
RUN python3 -m pip show torch torchvision torchaudio > /opt/pytorch-package-metadata.txt

# Final stage extends the upstream Webtop image while layering in the Jetson
# PyTorch stack and developer tooling.
FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all \
    PATH=/opt/jetson-python/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda/targets/aarch64-linux/lib:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies used inside the Webtop desktop session.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        python3 \
        python3-pip \
        python3-venv \
        python3-setuptools \
        build-essential \
        openmpi-bin \
        libopenmpi-dev \
        libopenblas-dev \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

# Bring the Python 3.10 runtime and Jetson-optimized torch stack into this
# image.
COPY --from=torch-builder /opt/python310-runtime.tgz /tmp/python310-runtime.tgz
COPY --from=torch-builder /opt/pytorch-site-packages.tgz /tmp/pytorch-site-packages.tgz
COPY --from=torch-builder /opt/cuda-runtime.tgz /tmp/cuda-runtime.tgz
RUN tar -C / -xzf /tmp/python310-runtime.tgz \
    && tar -C / -xzf /tmp/pytorch-site-packages.tgz \
    && tar -C / -xzf /tmp/cuda-runtime.tgz \
    && rm /tmp/python310-runtime.tgz /tmp/pytorch-site-packages.tgz /tmp/cuda-runtime.tgz \
    && ldconfig
COPY --from=torch-builder /opt/pytorch-package-metadata.txt /opt/pytorch-package-metadata.txt

# Configure python3/pip shims so the Jetson Python 3.10 runtime is preferred in
# interactive shells without disturbing system binaries.
RUN mkdir -p /opt/jetson-python/bin \
    && ln -sf /usr/bin/python3.10 /opt/jetson-python/bin/python3 \
    && ln -sf /usr/bin/python3.10 /opt/jetson-python/bin/python \
    && ln -sf /usr/local/bin/pip3.10 /opt/jetson-python/bin/pip3 \
    && ln -sf /usr/local/bin/pip3.10 /opt/jetson-python/bin/pip

# Configure pip to use NVIDIA's Jetson index for future Python package installs.
RUN python3 -m pip install --upgrade pip \
    && pip3 config set global.extra-index-url https://pypi.jetson-ai-lab.io/simple \
    && pip3 config set global.trusted-host pypi.jetson-ai-lab.io

# Add the higher-level ML tooling originally included with the image and ensure
# the Jetson host index is used for future installs.
RUN pip3 install --no-cache-dir \
        accelerate \
        sentencepiece \
        optimum \
    && pip3 install --no-cache-dir transformers \
    && pip3 install --no-cache-dir jupyterlab notebook

COPY custom-cont-init.d/ /custom-cont-init.d/
COPY custom-services.d/ /custom-services.d/
RUN chmod +x /custom-cont-init.d/* /custom-services.d/*

EXPOSE 22 8888
