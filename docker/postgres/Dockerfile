FROM postgres:17

# Instalar dependencias de build para pgTAP
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        postgresql-server-dev-17 \
    && git clone --depth 1 --branch v1.3.3 https://github.com/theory/pgtap.git /tmp/pgtap \
    && cd /tmp/pgtap \
    && make \
    && make install \
    # Instalar pg_prove (runner de tests TAP)
    && apt-get install -y --no-install-recommends libtest-harness-perl perl \
    && cpan TAP::Parser::SourceHandler::pgTAP \
    # Limpiar artefactos de build
    && apt-get purge -y build-essential git postgresql-server-dev-17 \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/pgtap
