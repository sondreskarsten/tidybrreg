# tidybrreg MCP server image.
#
# Built from the repository checkout, so the server always carries the
# tidybrreg at the same commit: core package from the repository root,
# tidybrregmcp from tidybrregmcp/. Nothing is pulled from CRAN for the two.
#
# Build (from the repository root):
#   docker build -f tidybrregmcp/Dockerfile -t tidybrreg-mcp .
# Run (stdio):
#   docker run -i tidybrreg-mcp
# Run (streamable HTTP on :8080):
#   docker run -p 8080:8080 -e MCP_TRANSPORT=http tidybrreg-mcp

ARG R_BASE=europe-north1-docker.pkg.dev/sondreskarsten-d7d14/r-images/r-base:latest
FROM ${R_BASE}

LABEL org.opencontainers.image.source="https://github.com/sondreskarsten/tidybrreg"
LABEL org.opencontainers.image.description="MCP server derived from the tidybrreg R package"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC \
    MCP_TRANSPORT=stdio PORT=8080

WORKDIR /build

# Core package first: its DESCRIPTION pins the dependency set.
COPY DESCRIPTION NAMESPACE LICENSE NEWS.md README.md ./core/
COPY R ./core/R
COPY man ./core/man
COPY data ./core/data
COPY inst ./core/inst
RUN Rscript -e 'install.packages(c("httpuv", "yyjsonr"), repos = c(CRAN = "https://cloud.r-project.org"))' \
 && R CMD INSTALL --no-docs ./core

COPY tidybrregmcp ./mcp
RUN R CMD INSTALL --no-docs ./mcp \
 && Rscript -e 'stopifnot(length(tidybrregmcp::mcp_tools()) == length(getNamespaceExports("tidybrreg")))'

WORKDIR /srv
RUN rm -rf /build

EXPOSE 8080
ENTRYPOINT ["Rscript", "-e", "tidybrregmcp::mcp_serve(Sys.getenv('MCP_TRANSPORT', 'stdio'))"]
