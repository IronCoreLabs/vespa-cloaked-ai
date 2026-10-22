# The el9 variant of https://github.com/vespa-engine/docker-image/blob/bce2da3/Dockerfile, running Vespa's
# published RPMs on JDK 25 instead of the JDK 21 they are packaged for. ironcore-alloy needs JDK 22+ and glibc 2.34+.
FROM docker.io/almalinux:9

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

# The vespa-base RPM still pulls in JDK 21; /opt/vespa/jdk, JAVA_HOME and the system java all point at 25.
RUN dnf -y install vespa-$VESPA_VERSION java-25-openjdk-devel && \
    ln -sfn /usr/lib/jvm/jre-25-openjdk /opt/vespa/jdk && \
    alternatives --set java "$(readlink -f /usr/lib/jvm/jre-25-openjdk/bin/java)" && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.title="Vespa on AlmaLinux 9 / JDK 25" \
      org.opencontainers.image.version="$VESPA_VERSION"

ENV JAVA_HOME=/usr/lib/jvm/jre-25-openjdk
ENV PATH="/opt/vespa/bin:/opt/vespa-deps/bin:${PATH}"
ENV VESPA_LOG_STDOUT="true"
ENV VESPA_LOG_FORMAT="vespa"
ENV VESPA_CLI_HOME=/tmp/.vespa
ENV VESPA_CLI_CACHE_DIR=/tmp/.cache/vespa

USER vespa

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
