FROM rocker/r-ver:4.5.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY egfr_slope_api.R /app/egfr_slope_api.R
COPY Compute_Slope.R /app/Compute_Slope.R
COPY run_egfr_slope_api.R /app/run_egfr_slope_api.R

RUN R -e "install.packages(c('plumber','jsonlite'), repos='https://cloud.r-project.org')"

ENV PORT=8787
EXPOSE 8787

CMD [\"Rscript\", \"run_egfr_slope_api.R\"]
