FROM ubuntu:22.04 AS builder

COPY apm-installer.tar.gz /opt/build/
RUN mkdir -p /opt/anjuna/bin && \
    tar -C /opt/anjuna/bin -xf /opt/build/apm-installer.tar.gz

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y curl gettext wget libssl-dev libcurl4-openssl-dev libjsoncpp-dev libboost-all-dev nlohmann-json3-dev jq && \
    wget https://packages.microsoft.com/repos/azurecore/pool/main/a/azguestattestation1/azguestattestation1_1.1.0_amd64.deb && \
    dpkg -i azguestattestation1_1.1.0_amd64.deb && \
    rm azguestattestation1_1.1.0_amd64.deb

FROM builder AS skr

WORKDIR /skr-client

RUN apt-get install -y git cmake build-essential

COPY openssl.patch .
RUN git clone https://github.com/Azure/confidential-computing-cvm-guest-attestation && \
    cd confidential-computing-cvm-guest-attestation/cvm-securekey-release-app && \
    git checkout b774ef5e935ee2f7596db49d10c3a308d6e10c7a && \
    git apply /skr-client/openssl.patch && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make

FROM builder AS runner

WORKDIR /root/

RUN apt autoremove -y && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    apt-get clean

COPY apm.hcl.tpl /opt/build/
COPY run.sh /opt/build/
COPY --from=skr /skr-client/confidential-computing-cvm-guest-attestation/cvm-securekey-release-app/build/AzureAttestSKR /usr/bin/AzureAttestSKR
COPY --from=skr /skr-client/confidential-computing-cvm-guest-attestation/LICENSE /opt/AzureAttestSKR/LICENSE

ENV APM_HOSTNAME=""
ENV APM_SA_NAME=""
ENV APM_KEYVAULT_NAME=""
ENV APM_PORT="8200"
ENV APM_MK_ID=""
ENV MAA_ENDPOINT=""

EXPOSE 8200

CMD ["/opt/build/run.sh"]
