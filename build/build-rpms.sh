#!/usr/bin/env bash
# Runs inside an almalinux:10 container. Builds Vespa RPMs from a git ref of the
# Vespa checkout mounted at /vespa-src and writes them, with repo metadata, to /out.
set -o errexit -o nounset -o pipefail

: "${VESPA_REF:?}"
: "${VESPA_VERSION:?}"

echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
dnf -y install dnf-plugins-core epel-release git rpmdevtools rpm-build createrepo_c make
/usr/bin/crb enable
git config --global --add safe.directory '*'

rm -rf /work/vespa
git clone --quiet --no-checkout /vespa-src /work/vespa
cd /work/vespa
git checkout --quiet "$VESPA_REF"

dnf config-manager --add-repo dist/vespa-engine.repo
./dist.sh "$VESPA_VERSION"
SPEC=~/rpmbuild/SPECS/vespa-$VESPA_VERSION.spec
dnf -y builddep "$SPEC"

# Up to at least v8.763.13 the spec filters the /opt/vespa-deps abseil sonames from the generated
# requires only on el8/el9, which leaves el10 RPMs requiring libraries no package provides.
rpmbuild -bb --nocheck \
  --define "debug_package %{nil}" \
  --define "_vespa_abseil_excludes |absl_[a-z_0-9]*" \
  --define "_cmake_extra_opts -DEXTRA_C_FLAGS=-g0" \
  --define "_binary_payload w10T4.zstdio" \
  "$SPEC"

rm -rf /out/*
cp -a ~/rpmbuild/RPMS/*/*.rpm /out/
createrepo_c /out
