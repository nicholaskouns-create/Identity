# Reproduce items 1-3 in a clean container. From the repository root:
#   docker build -f formal/e47/kernel-certificate/Dockerfile -t e47-cert .
#   docker run --rm e47-cert
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends coq make git python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /identity
COPY formal/e47/E47MatrixProjector.v formal/e47/E47OddsContraction.v formal/e47/E47OddsLink.v formal/e47/
COPY formal/e47/kernel-certificate formal/e47/kernel-certificate
COPY formal/e47/native-residual formal/e47/native-residual
COPY evidence/common-mode-auditor evidence/common-mode-auditor
RUN python3 -m venv /venv && /venv/bin/pip install --no-cache-dir -r formal/e47/native-residual/requirements.txt
ENV PATH=/venv/bin:$PATH
CMD make -C formal/e47/kernel-certificate check \
 && make -C formal/e47/native-residual check \
 && make -C formal/e47/native-residual falsify REPS=3 \
 && make -C evidence/common-mode-auditor smoke
