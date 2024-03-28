FROM rockylinux/rockylinux:9.3-ubi as builder
# registry.access.redhat.com/ubi9: CodeReady Builder does not provide swig on aarch64 !?!

RUN --mount=type=cache,target=/sources \
    dnf install 'dnf-command(config-manager)' --assumeyes && \
    dnf config-manager --enable crb --assumeyes && \
    dnf module enable swig --assumeyes && \
    dnf install --assumeyes rpm-build autoconf-archive automake gcc-c++ pcre2-devel m4 swig python python-devel git libcap-devel zlib-devel wget && \
    cd /root && \
    groupadd mock && adduser mockbuild && \
    curl -LO https://raw.githubusercontent.com/baruch/fakeprovide/master/fakeprovide && chmod u+x fakeprovide && \
    curl -LO https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    curl -LO https://corpora.fi.muni.cz/noske/current/centos7/manatee-open/manatee-open-2.225.8-1.el7.src.rpm && \
    curl -LO https://corpora.fi.muni.cz/noske/current/centos7/bonito-open/bonito-open-5.71.15-1.el7.src.rpm && \
    curl -LO https://corpora.fi.muni.cz/noske/current/centos7/gdex/gdex-4.13.2-1.el7.src.rpm && \
    curl -LO https://corpora.fi.muni.cz/noske/current/centos7/crystal-open/crystal-open-2.166.4-1.el7.src.rpm && \
    curl -LO https://mirror.stream.centos.org/9-stream/AppStream/$(uname -m)/os/Packages/bison-3.7.4-5.el9.$(uname -m).rpm && \
    curl -LO https://mirror.stream.centos.org/9-stream/AppStream/$(uname -m)/os/Packages/bison-runtime-3.7.4-5.el9.$(uname -m).rpm && \
    curl -LO https://foss.heptapod.net/openpyxl/openpyxl/-/archive/branch/3.1/openpyxl-branch-3.1.tar.gz && \
    curl -LO https://ftp5.gwdg.de/pub/opensuse/repositories/home:/mdecker/openSUSE_Tumbleweed/src/cronolog-1.7.2-105.89.src.rpm && \
    rpm -iv *src.rpm && rpm -iv bison*.rpm
RUN sed -i 's|amzn|rocky|g' ~/rpmbuild/SPECS/manatee-open.spec && rpmbuild -ba ~/rpmbuild/SPECS/manatee-open.spec
COPY bonito-open.patch crystal-open.patch /root
RUN patch -p0 < /root/bonito-open.patch && rpmbuild -ba ~/rpmbuild/SPECS/bonito-open.spec
RUN sed -i 's|amzn|rocky|g' ~/rpmbuild/SPECS/gdex.spec && rpmbuild -ba ~/rpmbuild/SPECS/gdex.spec
RUN (if [ $(uname -m) == aarch64 ]; then patch -p0 < /root/crystal-open.patch; fi) && rpmbuild -ba ~/rpmbuild/SPECS/crystal-open.spec
RUN rpmbuild -ba ~/rpmbuild/SPECS/cronolog.spec
RUN cd /root && git clone --depth 1 https://github.com/seveas/python-prctl.git && \
    cd python-prctl/ && sed -i 's|name = "python-prctl"|name = "python3-prctl"|' setup.py && ./setup.py bdist_rpm && \
    mv dist/*.src.rpm ~/rpmbuild/SRPMS && \
    mv dist/*.$(uname -m).rpm ~/rpmbuild/RPMS/$(uname -m)
RUN cd /root && tar -xf openpyxl-branch-3.1.tar.gz && cd openpyxl-branch-3.1 && sed -i "s|name='openpyxl'|name='python3-openpyxl'|" setup.py && \
    sed -i "1c#\!/usr/bin/python3" setup.py && ./setup.py bdist_rpm && \
    mv dist/*.src.rpm ~/rpmbuild/SRPMS && \
    mv dist/*.noarch.rpm ~/rpmbuild/RPMS/noarch
RUN cd /root && ./fakeprovide -s logos system-logos && ./fakeprovide -s httpd httpd && \
    mv *.noarch.rpm ~/rpmbuild/RPMS/noarch

FROM registry.access.redhat.com/ubi9-minimal

COPY run_lighttpd.sh import_logs.py \
     lighttpd.conf add_auth.sh \
     run.cgi test-run.cgi exportlib-py-pyxl-3-1.patch \
     /root/other_files/
COPY --from=builder /root/rpmbuild/RPMS /root/rpmbuild/SRPMS /root
COPY openapi /var/www/openapi
RUN rpm -i ~/noarch/epel-release-latest-9.noarch.rpm ~/noarch/fakeprovide-system-logos-*.el9.noarch.rpm \
           ~/noarch/fakeprovide-httpd-*.el9.noarch.rpm && \
    microdnf install -y glibc-all-langpacks lighttpd lighttpd-fastcgi m4 parallel python python3-pyyaml python3-lxml patch which findutils less vim nano && \
    microdnf clean all && \
    usermod -l www-data lighttpd && groupmod -n www-data lighttpd && \
    rpm -i ~/noarch/python3-openpyxl-*.noarch.rpm ~/$(uname -m)/python3-prctl-*.$(uname -m).rpm \
           ~/$(uname -m)/manatee-open-*.$(uname -m).rpm ~/$(uname -m)/manatee-open-python3-*.$(uname -m).rpm \
           ~/noarch/gdex-*.noarch.rpm ~/noarch/bonito-open-*.noarch.rpm \
           ~/noarch/crystal-open-*.noarch.rpm ~/$(uname -m)/cronolog-*.$(uname -m).rpm && \
    mv -v /root/other_files/run_lighttpd.sh /root/other_files/import_logs.py / && \
    mv -v /root/other_files/lighttpd.conf /root/other_files/add_auth.sh /etc/lighttpd/ && \
    mv -v /root/other_files/run.cgi /var/www/bonito/ && \
    mkdir -p /var/www/test/bonito/ && \
    mv -v /root/other_files/test-run.cgi /var/www/test/bonito/run.cgi && \
	pushd /usr/lib/python3.9/site-packages/bonito/ && \
	patch -p0 < /root/other_files/exportlib-py-pyxl-3-1.patch && \
	popd && \
    localedef -c -i en_IE -f UTF-8 en_IE.UTF-8; echo returned $? && \
    mkdir -p /var/www/test/bonito/ && \
    mkdir -p /usr/lib/python3.9/dist-packages && \
    mv /usr/lib/python3.9/site-packages/bonito /usr/lib/python3.9/dist-packages && \
    cp -a /usr/lib/python3.9/dist-packages/bonito /usr/lib/python3.9/site-packages/bonito.init && \
    ln -s /usr/lib/python3.9/dist-packages/bonito /usr/lib/python3.9/site-packages/bonito && \
    mv /var/www/crystal /var/www/crystal.init && \
    mkdir -p /tmp/lighttpd && chown www-data:www-data /tmp/lighttpd && \
    mkdir -p /var/lib/bonito/jobs && chown www-data:www-data /var/lib/bonito/jobs && \
    mkdir -p /var/lib/bonito/cache && chown www-data:www-data /var/lib/bonito/cache && \
    mkdir -p /var/cache/lighttpd/compress && chown www-data:www-data /var/cache/lighttpd/compress && \
    mkdir -p /var/www/crystal && chown www-data:www-data /var/www/crystal && \
    mkdir -p /var/lib/manatee/data && chown www-data:www-data /var/lib/manatee/data

ENV MANATEE_REGISTRY=/var/lib/manatee/registry \
    HTTPD_ERROR_LOGFILE=/dev/fd/3 \
    HTTPD_ACCESS_LOGFILE="|/usr/sbin/cronolog -c -S /var/log/lighttpd/access.log /var/log/lighttpd/%Y-%m-%d-access.log" \
    LOGIDSITE=0 \
    HTPASSWD_FILE="" \
    CORPLIST="" \
    LANG="en_IE.UTF-8"
#@INJECT_USER@

USER root
USER www-data
WORKDIR /home/user
VOLUME /var/lib/manatee/registry /var/log/lighttpd /var/lib/manatee/data /var/lib/bonito
# optionally /var/www/crystal
EXPOSE 8080

HEALTHCHECK --timeout=1s \
  CMD curl -A "healthcheck" -f http://localhost:8080/bonito/run.cgi || exit 1
CMD ["/bin/sh", "/run_lighttpd.sh"]
