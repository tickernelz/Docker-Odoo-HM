FROM ubuntu:bionic

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8
ARG DEBIAN_FRONTEND=noninteractive

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            python3-wheel \
            python3-setuptools \
            python3-pip \
            # python3.7 \
            # libpython3.7 \
            curl \
            wget \
            gnupg \
            libpq-dev \
            libsasl2-2 \
            libldap-2.4-2 \
            libxml2 \
            libxmlsec1 \
            libxslt1.1 \
            npm \
            node-less \
            # python3-yaml \
        && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1 \
        # && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 2 \
        && update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1 \
        && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2 \
        && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb \
        && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN set -x; \
        echo 'deb https://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main' > etc/apt/sources.list.d/pgdg.list \
        && export GNUPGHOME="$(mktemp -d)" \
        && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
        && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
        && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
        && gpgconf --kill all \
        && rm -rf "$GNUPGHOME" \
        && apt-get update  \
        && apt-get install -y postgresql-client \
        && rm -rf /var/lib/apt/lists/*

# Install Odoo
ENV ODOO_VERSION 14.0
ARG ODOO_RELEASE=20210212
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && apt-get update \
    && wget http://ftp.kr.debian.org/debian/pool/main/i/init-system-helpers/init-system-helpers_1.60_all.deb \
    && apt-get -y install --no-install-recommends ./init-system-helpers_1.60_all.deb \
    && wget http://kr.archive.ubuntu.com/ubuntu/pool/universe/x/xlwt/python3-xlwt_1.3.0-3_all.deb \
    && apt-get -y install --no-install-recommends ./python3-xlwt_1.3.0-3_all.deb \
    && wget http://ftp.br.debian.org/debian/pool/main/p/python-num2words/python3-num2words_0.5.6-1_all.deb \
    && apt-get -y install --no-install-recommends ./python3-num2words_0.5.6-1_all.deb \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
