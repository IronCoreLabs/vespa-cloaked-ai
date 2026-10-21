# AlmaLinux 10 variant of https://github.com/vespa-engine/docker-image/blob/bce2da3/Dockerfile.
# Expects the RPMs from `make rpms` as the `rpms` build context.
FROM docker.io/almalinux:10

ARG VESPA_VERSION

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    echo "fastestmirror=0"         >> /etc/dnf/dnf.conf && \
    dnf -y install dnf-plugins-core epel-release && \
    dnf -y config-manager --add-repo https://github.com/vespa-engine/vespa/raw/master/dist/vespa-engine.repo && \
    /usr/bin/crb enable && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

COPY start-container.sh /usr/local/bin/start-container.sh

RUN groupadd -g 1000 vespa && \
    useradd -u 1000 -g vespa -d /opt/vespa -s /sbin/nologin vespa

RUN --mount=type=bind,from=rpms,target=/rpms,ro \
    echo -e "[vespa-rpms-local]\nname=Local Vespa RPMs\nbaseurl=file:///rpms/\nenabled=1\ngpgcheck=0" > /etc/yum.repos.d/vespa-rpms-local.repo && \
    dnf -y install vespa-$VESPA_VERSION && \
    dnf clean all && \
    rm -f /etc/yum.repos.d/vespa-rpms-local.repo && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.title="Vespa on AlmaLinux 10 / JDK 25" \
      org.opencontainers.image.version="$VESPA_VERSION"

ENV PATH="/opt/vespa/bin:/opt/vespa-deps/bin:${PATH}"
ENV VESPA_LOG_STDOUT="true"
ENV VESPA_LOG_FORMAT="vespa"
ENV VESPA_CLI_HOME=/tmp/.vespa
ENV VESPA_CLI_CACHE_DIR=/tmp/.cache/vespa

USER vespa

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
