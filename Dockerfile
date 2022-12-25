FROM mrnonz/alpine-git-curl as download
# cf. https://github.com/AbdBarho/stable-diffusion-webui-docker/blob/master/services/AUTOMATIC1111/Dockerfile

SHELL ["/bin/sh", "-ceuxo", "pipefail"]

WORKDIR /root
RUN echo 'mkdir -p repositories/"$1" && cd repositories/"$1" && git init && git remote add origin "$2" && git fetch origin "$3" --depth=1 && git reset --hard "$3"' >clone.sh

RUN git clone --depth=1 https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
WORKDIR stable-diffusion-webui/

RUN /bin/sh /root/clone.sh taming-transformers https://github.com/CompVis/taming-transformers.git 24268930bf1dce879235a7fddd0b2355b84d7ea6 \
  && rm -rf data assets **/*.ipynb

RUN /bin/sh /root/clone.sh stable-diffusion-stability-ai https://github.com/Stability-AI/stablediffusion.git 47b6b607fdd31875c9279cd2f4f16b92e4ea958e \
  && rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN /bin/sh /root/clone.sh CodeFormer https://github.com/sczhou/CodeFormer.git c5b4593074ba6214284d6acd5f1719b6c5d739af \
  && rm -rf assets inputs

RUN /bin/sh /root/clone.sh BLIP https://github.com/salesforce/BLIP.git 48211a1594f1321b00f14c9f7a5b4813144b2fb9
RUN /bin/sh /root/clone.sh k-diffusion https://github.com/crowsonkb/k-diffusion.git 5b3af030dd83e0297272d861c19477735d0317ec
RUN /bin/sh /root/clone.sh clip-interrogator https://github.com/pharmapsychotic/clip-interrogator 2486589f24165c8e3b303f84e9dbbea318df83e8

RUN mkdir interrogate

# ==============================================================================

FROM nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04
LABEL maintainer="hnmr293"

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl \
      wget \
      git \
      bzip2 \
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

# install webui to /data/stable-diffusion-webui
WORKDIR /data
COPY --from=download --chown=sd_user:sd_user /root/stable-diffusion-webui /data/stable-diffusion-webui

WORKDIR /data/stable-diffusion-webui/

# install requirements
ENV PIP_PREFER_BINARY=1 PIP_NO_CACHE_DIR=1
RUN python -m venv venv
RUN --mount=type=cache,target=/root/.cache/pip \
    . ./venv/bin/activate && \
    pip install triton torch==1.13+cu117 torchvision==0.14+cu117 --extra-index-url https://download.pytorch.org/whl/cu117 && \
    deactivate
RUN --mount=type=cache,target=/root/.cache/pip \
    . ./venv/bin/activate && \
    cp repositories/clip-interrogator/data/* interrogate/ && \
    pip install -r repositories/CodeFormer/requirements.txt && \
    deactivate
RUN --mount=type=cache,target=/root/.cache/pip \
    . ./venv/bin/activate && \
    pip install opencv-python-headless \
                git+https://github.com/TencentARC/GFPGAN.git@8d2447a2d918f8eba5a4a01463fd48e45126a379 \
                git+https://github.com/openai/CLIP.git@d50d76daa670286dd6cacf3bcd80b5e4823fc8e1 \
                git+https://github.com/mlfoundations/open_clip.git@bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b \
                pyngrok && \
    deactivate
RUN --mount=type=cache,target=/root/.cache/pip \
    . ./venv/bin/activate && \
    pip install -r requirements_versions.txt && \
    deactivate
RUN --mount=type=cache,target=/root/.cache/pip \
    . ./venv/bin/activate && \
    pip install -U opencv-python-headless 'transformers>=4.24' && \
    deactivate

# install xformers
RUN curl -sS -L https://anaconda.org/xformers/xformers/0.0.15.dev343%2Bgit.1b1fd8a/download/linux-64/xformers-0.0.15.dev343%2Bgit.1b1fd8a-py310_cu11.7_pyt1.13.tar.bz2 \
    | tar -jxf - --exclude info -C venv

RUN mkdir /data/bin
COPY --chown=sd_user:sd_user run-sd install-model install-model-vae install-vae /data/bin/
ENV PATH="/data/bin:$PATH"

CMD [ "run-sd" ]
