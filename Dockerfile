# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile — installs all 9 ecosystem package manifests
# Node 20, Python 3.12, Java 17, Deno, .NET 8, Ruby 3.3, Go 1.22,
# PHP 8.3/Composer, Rust stable — all dependencies pre-installed.
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# ── System prerequisites ────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget unzip git ca-certificates gnupg \
    build-essential pkg-config libssl-dev \
    libyaml-dev zlib1g-dev libreadline-dev \
    php8.3 php8.3-cli php8.3-mbstring php8.3-xml php8.3-curl php8.3-zip \
    python3.12 python3.12-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Java 17 (Eclipse Temurin) ────────────────────────────────────────────────
RUN wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
      | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] \
       https://packages.adoptium.net/artifactory/deb noble main" \
       > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update && apt-get install -y temurin-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# ── Maven 3.9 ────────────────────────────────────────────────────────────────
ARG MAVEN_VERSION=3.9.8
RUN curl -fsSL "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn

# ── Deno ─────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh

# ── .NET 8 SDK ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 \
      --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet

# ── Ruby 3.3 (rbenv) ─────────────────────────────────────────────────────────
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
RUN git clone --depth=1 https://github.com/rbenv/rbenv.git "${RBENV_ROOT}" \
    && git clone --depth=1 https://github.com/rbenv/ruby-build.git "${RBENV_ROOT}/plugins/ruby-build" \
    && rbenv install 3.3.3 && rbenv global 3.3.3 \
    && gem install bundler --no-document

# ── Go 1.22 ──────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.22.4
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
      | tar -xz -C /usr/local
ENV PATH="/usr/local/go/bin:${PATH}"

# ── PHP Composer ─────────────────────────────────────────────────────────────
RUN curl -sS https://getcomposer.org/installer \
      | php -- --install-dir=/usr/local/bin --filename=composer

# ── Rust / Cargo ─────────────────────────────────────────────────────────────
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH="${CARGO_HOME}/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable

# ─────────────────────────────────────────────────────────────────────────────
# Copy manifests and install all dependencies
# ─────────────────────────────────────────────────────────────────────────────
WORKDIR /app
COPY . .

RUN npm install
RUN pip install --no-cache-dir -r requirements.txt
RUN mvn dependency:resolve --no-transfer-progress -f pom.xml
RUN deno cache --config deno.json
RUN dotnet restore packages.csproj
RUN bundle install
RUN go mod download
RUN composer install --no-interaction --prefer-dist --optimize-autoloader
RUN cargo fetch

CMD ["echo", "All ecosystem packages installed successfully!"]
