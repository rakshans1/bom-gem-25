ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.2
ARG DEBIAN_VERSION=trixie-20250811-slim
ARG NODEJS_VERSION=22
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

ARG NODEJS_VERSION
ARG GIT_REVISION

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential wget git curl unzip ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN update-ca-certificates

RUN curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN npm install -g pnpm@9.15.0 turbo

# Install litestream
ARG LITESTREAM_VERSION=0.3.13
RUN wget https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-amd64.deb \
    && dpkg -i litestream-v${LITESTREAM_VERSION}-linux-amd64.deb

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets


COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/slides/package.json apps/slides/

# Install JavaScript dependencies
RUN pnpm install --frozen-lockfile

# Copy application code
COPY apps apps

RUN turbo run build

# Compile the release
RUN mix compile

# compile assets
RUN mix assets.deploy


# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/


COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}


RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses6 locales wget ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN update-ca-certificates

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/gem ./

# Copy Litestream binary from build stage
COPY --from=builder /usr/bin/litestream /usr/bin/litestream
COPY litestream.sh /app/bin/litestream.sh
COPY litestream.yml /etc/litestream.yml

USER nobody

# Run litestream script as entrypoint
ENTRYPOINT ["/bin/bash", "/app/bin/litestream.sh"]

CMD ["/app/bin/server"]
