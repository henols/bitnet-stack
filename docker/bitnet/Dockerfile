FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    software-properties-common \
    wget \
    build-essential \
    cmake \
 && rm -rf /var/lib/apt/lists/*

RUN wget -O /tmp/llvm.sh https://apt.llvm.org/llvm.sh \
 && chmod +x /tmp/llvm.sh \
 && /tmp/llvm.sh 18 \
 && ln -sf /usr/bin/clang-18 /usr/local/bin/clang \
 && ln -sf /usr/bin/clang++-18 /usr/local/bin/clang++ \
 && rm -f /tmp/llvm.sh

ENV CC=clang
ENV CXX=clang++

WORKDIR /opt
RUN git clone --recursive https://github.com/microsoft/BitNet.git
RUN sed -i 's/int8_t \* y_col = y + col \* by;/const int8_t * y_col = y + col * by;/' /opt/BitNet/src/ggml-bitnet-mad.cpp

WORKDIR /opt/BitNet
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip setuptools wheel \
 && pip install -r requirements.txt \
 && pip install "huggingface_hub[cli]"

EXPOSE 8080
VOLUME ["/models"]

COPY docker/bitnet/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
