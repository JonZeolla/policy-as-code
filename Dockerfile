# syntax=docker/dockerfile:1

ARG EASY_INFRA_VERSION=2025.01.04
ARG PYTHON_VERSION
# TARGETPLATFORM is special cased by docker and doesn't need an initial ARG; if you plan to use it repeatedly you must add ARG TARGETPLATFORM between uses
# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
FROM --platform=$TARGETPLATFORM seiso/easy_infra:${EASY_INFRA_VERSION}-ansible AS base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Since we use TARGETARCH below, we need to re-scope it
ARG TARGETARCH

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1

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

COPY lab-resources /etc/app/lab-resources
COPY requirements.yml /etc/app/requirements.yml

# A privileged user is necessary in order to build and to run the entrypoint
# hadolint ignore=DL3002
USER root
RUN ansible-galaxy collection build /etc/app/lab-resources/ansible/jonzeolla/labs \
 && ansible-galaxy collection install ./jonzeolla-labs-*.tar.gz \
 && rm ./jonzeolla-labs-*.tar.gz \
 && ansible-galaxy collection install -r /etc/app/requirements.yml \
 && curl https://get.docker.com -o get-docker.sh \
 # Avoid setting the VERSION env var during get-docker.sh
 && unset VERSION \
 && bash ./get-docker.sh \
 && rm get-docker.sh


ARG PYTHON_VERSION
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

WORKDIR /usr/src/app
# Install the deps
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen \
            --no-install-project \
            --no-dev

# Install the project with the project included
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen \
            --no-dev

FROM base AS final

WORKDIR /usr/src/app
ENV PATH="/usr/src/app/.venv/bin:${PATH}"
# Quick hack to ensure deps are loaded, not optimal
ENV PYTHONPATH=/usr/src/app/.venv/lib/python${PYTHON_VERSION}/site-packages
COPY --from=builder /usr/src/app/.venv .venv
COPY ./valid_ip.py /usr/src/app/valid_ip.py

ENV ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH}:/etc/app/ansible/roles/"
COPY ansible/roles/ /etc/app/ansible/roles/
COPY policy-as-code.yml /etc/app/policy-as-code.yml
COPY vars /etc/app/vars
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
