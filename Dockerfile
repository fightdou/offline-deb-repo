FROM ubuntu:22.04 as os-focal
ARG OS_VERSION=focal
ARG DEP_PACKAGES="apt-transport-https ca-certificates curl wget gnupg dpkg-dev software-properties-common"

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apt update \
    && apt install -y --no-install-recommends $DEP_PACKAGES \
    && curl -fsSL "https://download.docker.com/linux/debian/gpg" | apt-key add - \
    && echo "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu ${OS_VERSION} stable" > /etc/apt/sources.list.d/docker.list\
    && curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list\
    && add-apt-repository --yes --update ppa:ansible/ansible\
    && apt update -qq

WORKDIR /ubuntu/${OS_VERSION}
COPY packages.yaml .

COPY --from=mikefarah/yq:4.11.1 /usr/bin/yq /usr/bin/yq
RUN yq eval '.ubuntu.common[],.ubuntu.ceph[],.ubuntu.docker[],.ubuntu.kubernetes[]' packages.yaml > packages.list \
    && dpkg --get-selections | grep -v deinstall | cut -f1 | cut -d ':' -f1 >> packages.list \
    && sort -u packages.list | xargs apt-get install --reinstall --print-uris | awk -F "'" '{print $2}' | grep -v '^$' | sort -u > packages.urls

RUN wget -q -x -P ${OS_VERSION} -i packages.urls \
    && dpkg-scanpackages ${OS_VERSION} | gzip -9c > ${OS_VERSION}/Packages.gz

FROM httpd:latest
COPY --from=os-focal /ubuntu /usr/local/apache2/htdocs/

