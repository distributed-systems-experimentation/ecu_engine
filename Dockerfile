# Use a minimal Rust image for building
FROM rust:alpine AS builder

# ENV CARGO_REGISTRIES_KELLNR_INDEX="http://host.docker.internal:8000/api/v1/crates/"


RUN apk add --no-cache openssl-dev musl-dev
RUN rustup target add aarch64-unknown-linux-musl

# Set the working directory
WORKDIR /app

COPY . .

# Build the application
# Leverage cache mounts for Cargo registry and target directories
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --target aarch64-unknown-linux-musl --release \
    && strip /app/target/aarch64-unknown-linux-musl/release/ecu_engine \
    && mkdir -p /app/bin \
    && cp /app/target/aarch64-unknown-linux-musl/release/ecu_engine /app/bin/



# Use a minimal base image for the final stage
FROM scratch


# Copy the built executable from the builder stage
COPY --from=builder /app/bin/ecu_engine ./ecu_engine

# Command to run the executable
CMD ["./ecu_engine"]