FROM ubuntu:xenial
LABEL maintainer="tickernelz <zhafronadani@gmail.com>"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8
ARG DEBIAN_FRONTEND=noninteractive

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            apt-transport-https \
            libcurl3-gnutls \
            ca-certificates \
            fonts-noto-cjk \
            libcurl4-openssl-dev \
            libssl-dev \
            curl \
            wget \
            dirmngr \
            gnupg \
            node-less \
            npm \
            gettext \
            build-essential \
            librsync-dev \
            python-gevent \
            python-ldap \
            python-pip \
            python-qrcode \
            python-renderpm \
            python-vobject \
            python-watchdog \
            python-dev \
        && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb \
        && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Install latest postgresql-client
RUN set -x; \
        echo 'deb https://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > etc/apt/sources.list.d/pgdg.list \
        && export GNUPGHOME="$(mktemp -d)" \
        && apt-get update  \
        && repokey='7FCC7D46ACCC4CF8' \
        && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
        && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8 \
        && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
        && rm -rf "$GNUPGHOME" \
        && apt-get update  \
        && apt-get install -y postgresql-client \
        && rm -rf /var/lib/apt/lists/*

# Install Odoo
RUN set -x; \
        wget -O - https://nightly.odoo.com/odoo.key | apt-key add - \
        && echo "deb http://nightly.odoo.com/10.0/nightly/deb/ ./" >> /etc/apt/sources.list \
        && apt-get update \
        && apt-get -y install -f odoo \
        && rm -rf /var/lib/apt/lists/* odoo.deb

# Install PIP Modules
RUN set -x; \
        curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py \
        && python2 get-pip.py \
        && python2 -m pip install numpy psycogreen==1.0 openpyxl==2.0.2 xlrd==1.0.0 cachetools==2.0.1 unittest2 pdfkit==0.6.1 duplicity==0.8.20 BeautifulSoup==3.2.2 bcrypt==3.1.7 beautifulsoup4==4.9.3 num2words==0.5.10 pycurl wdb \
        && python2 -m pip cache purge \
        && rm -rf /var/lib/apt/lists/*

# Remove Unused Modules
RUN set -x; \
        mkdir /mnt/temp \
        && cd /usr/lib/python2.7/dist-packages/odoo/addons \
        && mv {account_cash_basis_base_account,account_lock,auth_signup,base,bus,l10n_be_intrastat_2019,l10n_fr_certification,l10n_fr_pos_cert,l10n_fr_sale_closing,mail,payment_stripe_sca,test_access_rights,test_assetsbundle,test_convert,test_converter,test_documentation_examples,test_exceptions,test_impex,test_inherit,test_inherits,test_limits,test_lint,test_mimetypes,test_new_api,test_pylint,test_read_group,test_rpc,test_uninstall,test_workflow,website,__init__.py} /mnt/temp \
        && rm -r * \
        && cd /mnt/temp \
        && mv {account_cash_basis_base_account,account_lock,auth_signup,base,bus,l10n_be_intrastat_2019,l10n_fr_certification,l10n_fr_pos_cert,l10n_fr_sale_closing,mail,payment_stripe_sca,test_access_rights,test_assetsbundle,test_convert,test_converter,test_documentation_examples,test_exceptions,test_impex,test_inherit,test_inherits,test_limits,test_lint,test_mimetypes,test_new_api,test_pylint,test_read_group,test_rpc,test_uninstall,test_workflow,website,__init__.py} /usr/lib/python2.7/dist-packages/odoo/addons

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]
# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
