FROM nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04
LABEL maintainer="hnmr293"

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl \
      wget \
      git \
      byobu \
      python3.10 \
      python3.10-venv \
      python3.10-dev \
      python-is-python3 \
      libglib2.0-0 \
      libgl1-mesa-dev && \
    apt-get autoremove -y && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /data && \
    chmod 777 /data

RUN adduser sd_user
USER sd_user

WORKDIR /data

# install webui to /data/stable-diffusion-webui and xformers
RUN wget -qO- https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh | install_dir=/data bash /dev/stdin --exit && \
    cd /data/stable-diffusion-webui && \
    . ./venv/bin/activate && \
    pip install --no-cache-dir triton accelerate torch==1.13+cu117 torchvision==0.14+cu117 --extra-index-url https://download.pytorch.org/whl/cu117 && \
    deactivate && \
    curl -sS -L https://anaconda.org/xformers/xformers/0.0.15.dev343%2Bgit.1b1fd8a/download/linux-64/xformers-0.0.15.dev343%2Bgit.1b1fd8a-py310_cu11.7_pyt1.13.tar.bz2 -o /tmp/xformers.tar.bz2 && \
    tar -jxf /tmp/xformers.tar.bz2 --exclude info -C /data/stable-diffusion-webui/venv && \
    rm /tmp/xformers.tar.bz2

RUN cd /data/stable-diffusion-webui/models/Stable-diffusion && \
    curl -O -L https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt

RUN mkdir /data/bin
COPY --chown=sd_user:sd_user run-sd install-model install-model-vae install-vae /data/bin/
ENV PATH="/data/bin:$PATH"

CMD [ "run-sd" ]
