FROM perl:5.40-slim

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     build-essential \
     ca-certificates \
     cpm \
     libvips-tools \
   && rm -rf /var/lib/apt/lists/*

COPY . /app

RUN if [ -f cpanfile ]; then cpm install -g --without-recommends --cpanfile cpanfile; fi

EXPOSE 5000

CMD ["plackup", "-Ilib", "-s", "Starman", "--workers", "1", "-o", "0.0.0.0", "-p", "5000", "app.psgi"]
