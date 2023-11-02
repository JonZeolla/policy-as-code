# syntax=docker/dockerfile:1

ARG EASY_INFRA_VERSION=2023.10.06
# TARGETPLATFORM is special cased by docker and doesn't need an inital ARG; if you plan to use it repeatedly you must add ARG TARGETPLATFORM between uses
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
FROM --platform=$TARGETPLATFORM seiso/easy_infra:${EASY_INFRA_VERSION}-ansible AS base
# Since we use TARGETARCH below, we need to re-scope it
ARG TARGETARCH

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG VERSION
ARG COMMIT_HASH

LABEL org.opencontainers.image.title="Policy as Code lab setup"
LABEL org.opencontainers.image.description="Setup Jon Zeolla's Policy as Code lab"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.vendor="Jon Zeolla"
LABEL org.opencontainers.image.url="https://jonzeolla.com"
LABEL org.opencontainers.image.source="https://github.com/JonZeolla/policy-as-code"
LABEL org.opencontainers.image.revision="${COMMIT_HASH}"
LABEL org.opencontainers.image.licenses="NONE"

# Configure easy_infra
ARG SILENT="true"
ENV SILENT="${SILENT}"

ARG LAB_RESOURCES_VERSION
# A privileged user is necessary in order to build and to run the entrypoint
# hadolint ignore=DL3002
USER root
RUN ansible-galaxy collection install git+https://github.com/jonzeolla/lab-resources#/ansible/jonzeolla/,v${LAB_RESOURCES_VERSION} \
 && ansible-galaxy collection install "amazon.aws:<7.0.0" \
 && ansible-galaxy collection install "community.crypto:<3.0.0" \
 && ansible-galaxy collection install "community.docker:<4.0.0" \
 # See breaking changes for ansible 2.10 in https://github.com/ansible-collections/community.general/releases/tag/8.0.0
 && ansible-galaxy collection install "community.general:<8.0.0" \
 && curl https://get.docker.com -o get-docker.sh \
 # Avoid setting the VERSION env var in get-docker.sh
 && unset VERSION \
 && bash ./get-docker.sh \
 && rm get-docker.sh \
 && mkdir -p "${HOME}/logs"

ENV ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH}:/etc/app/ansible/roles/"

COPY policy-as-code.yml /etc/app/policy-as-code.yml
COPY vars /etc/app/vars
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ansible/roles/ /etc/app/ansible/roles/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
