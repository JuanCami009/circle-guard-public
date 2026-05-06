FROM locustio/locust
USER root
COPY . /mnt/locust/
RUN chown -R locust:locust /mnt/locust
USER locust
WORKDIR /mnt/locust
