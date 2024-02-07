ARG CI_REGISTRY_IMAGE
ARG TAG
FROM ubuntu:22.04
LABEL maintainer="nathalie.casati@chuv.ch"

ARG DEBIAN_FRONTEND=noninteractive
ARG CARD
ARG CI_REGISTRY
ARG APP_NAME
ARG APP_VERSION

LABEL app_version=$APP_VERSION
LABEL app_tag=$TAG

WORKDIR /apps/${APP_NAME}

ARG VERSION
ARG UPDATE

#matlab-runtime
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
    ca-certificates curl unzip libxt6 && \
    mkdir files && \
    curl -sSO https://ssd.mathworks.com/supportfiles/downloads/${VERSION}/Release/${UPDATE}/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_${VERSION}_Update_${UPDATE}_glnxa64.zip && \
    unzip -q -d files MATLAB_Runtime_${VERSION}_Update_${UPDATE}_glnxa64.zip && \
    ./files/install -agreeToLicense yes -mode silent && \
    rm -rf MATLAB_Runtime_${VERSION}_Update_${UPDATE}_glnxa64.zip files && \
    rm -rf /usr/local/MATLAB/MATLAB_Runtime/v9*/sys/os/glnxa64/libstdc++.so.6 && \
    apt-get remove -y --purge curl unzip && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#brainstorm
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
    curl unzip default-jre && \
    #curl -sSJ -O http://neuroimage.usc.edu/bst/getupdate.php?d=bst_bin_R2021a_${APP_VERSION}.zip && \
    curl -sSJ -O "http://neuroimage.usc.edu/bst/getupdate.php?c=UbsM09&src=0&bin=1" && \
    #curl -sSJ -O http://neuroimage.usc.edu/bst/getupdate.php?c=UbsM09 && \
    mkdir ./install && \
    #unzip -q -d ./install bst_bin_R2021a_${APP_VERSION}.zip && \
    #rm -rf bst_bin_R2021a_${APP_VERSION}.zip && \
    unzip -q -d ./install brainstorm_*_bin.zip && \
    rm brainstorm_*_bin.zip && \
    apt-get remove -y --purge curl unzip && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV APP_SPECIAL="no"
ENV APP_CMD="sleep 60;/apps/${APP_NAME}/install/brainstorm3/bin/R2022b/brainstorm3.command /usr/local/MATLAB/MATLAB_Runtime/R2022b"
ENV PROCESS_NAME="brainstorm3.jar"
ENV APP_DATA_DIR_ARRAY="brainstorm_db .brainstorm"
#ENV APP_DATA_DIR_ARRAY="brainstorm_db .brainstorm .mcrCache9.8"
ENV DATA_DIR_ARRAY=""

#HEALTHCHECK --interval=10s --timeout=10s --retries=5 --start-period=30s \
#  CMD sh -c "/apps/${APP_NAME}/scripts/process-healthcheck.sh \
#  && /apps/${APP_NAME}/scripts/ls-healthcheck.sh /home/${HIP_USER}/nextcloud/"

COPY ./scripts/ scripts/

ENTRYPOINT ["./scripts/docker-entrypoint.sh"]
