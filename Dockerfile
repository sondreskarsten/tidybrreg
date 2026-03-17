ARG R_VERSION=4.4.1
FROM rocker/r-ver:${R_VERSION}

LABEL org.opencontainers.image.source="https://github.com/sondreskarsten/tidybrreg"
LABEL org.opencontainers.image.description="CI test image for tidybrreg R package"

# System dependencies for arrow, igraph/tidygraph, httr2/curl, SSL
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4-openssl-dev \
    libssl-dev \
    libglpk-dev \
    libxml2-dev \
    libgmp3-dev \
    cmake \
    git \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pak for fast dependency resolution
RUN Rscript -e 'install.packages("pak", repos = sprintf( \
      "https://r-lib.github.io/p/pak/stable/%s/%s/%s", \
      .Platform$pkgType, R.Version()$os, R.Version()$arch))'

WORKDIR /tidybrreg

# Copy DESCRIPTION first — this layer caches until deps change
COPY DESCRIPTION .

# Install ALL dependencies (Imports + Suggests) including heavy ones
RUN Rscript -e 'pak::local_install_deps(dependencies = TRUE)'

# Install CI tooling
RUN Rscript -e 'pak::pkg_install(c("rcmdcheck", "covr"))'

# Copy full package source
COPY . .

# Install package itself
RUN Rscript -e 'pak::local_install(dependencies = FALSE)'

CMD ["Rscript", "-e", "testthat::test_local(reporter = 'summary')"]
