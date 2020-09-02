FROM continuumio/miniconda:latest
LABEL authors="Yan Zhou" \
      description="Docker image for angelovangel/nxf-ont"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nxf-ont-1.0/bin:$PATH

# Dump the details of the installed packages to a file for posterity
#RUN conda env export --name nxf-ont-1.0 > nxf-ont-1.0.yml
