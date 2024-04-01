FROM debian:bookworm

# Install required packages for building the kernel
RUN set -x \
 && apt-get update && apt-get install -y \
      build-essential \
      bc \
      xz-utils \
      libncurses-dev \
      wget \
      libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm \
      git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison \
      strace \
      python3 python3-pip python3-venv \
      graphviz \
      bear jq \
      moreutils \
      texinfo gperf libunistring-dev debhelper-compat help2man coreutils \
      bpftrace \
 && rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN mkdir -p /out
RUN set -x \
 && git clone https://github.com/bmwcarit/stracepy /stracepy \
 && cd /stracepy \
 && pip3 install -r requirements.txt \
 && python3 setup.py install 
RUN set -x \
 && git clone https://github.com/nexB/tracecode-toolkit-strace /tracecode-toolkit-strace \
 && cd /tracecode-toolkit-strace \
 && pip3 install -r requirements.txt \
 && python3 setup.py install 
RUN set -x \
 && git clone https://github.com/lindenb/makefile2graph /makefile2graph \
 && cd /makefile2graph \
 && make \
 && make install

ADD ./gregkh-linux/scripts/trace_kernel_build.sh /trace_kernel_build.sh
ADD entrypoint.sh /entrypoint.sh
RUN set -x \
 && chmod +x /entrypoint.sh \
 && chmod +x /trace_kernel_build.sh \
 && ulimit -l 8192
ENTRYPOINT [ "/entrypoint.sh" ]

WORKDIR /src
CMD [ "all" ]
