FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install iverilog, yosys, and git
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        iverilog \
        yosys \
        git \
        ca-certificates \
        make \
    && rm -rf /var/lib/apt/lists/*

# Clone the IHP PDK (standard cell library only, shallow)
RUN git clone --depth 1 https://github.com/IHP-GmbH/IHP-Open-PDK.git /opt/IHP-Open-PDK

ENV IHP_PDK=/opt/IHP-Open-PDK

WORKDIR /work
COPY . /work

# Default: run all steps
CMD ["sh", "-c", "echo '========== RTL Simulation ==========' && make test && echo '========== Synthesis (IHP SG13G2) ==========' && make synth && echo '========== Gate-Level Simulation ==========' && make test_gl"]
