FROM rust:alpine AS base

# Install build dependencies
RUN apk add --no-cache musl-dev build-base

RUN cargo install cargo-chef
RUN rustup target add aarch64-unknown-linux-musl

# Step 1: Dependency planning
FROM base AS planner
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo chef prepare --recipe-path recipe.json

# Step 2: Build dependencies only
FROM base AS builder
WORKDIR /app
COPY --from=planner /app/recipe.json recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo chef cook --release --target aarch64-unknown-linux-musl --recipe-path recipe.json

# Step 3: Build application
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo build --release --target aarch64-unknown-linux-musl \
    && strip /app/target/aarch64-unknown-linux-musl/release/ecu_engine


# Use a minimal base image for the final stage
FROM scratch

# Copy the built executable from the builder stage
COPY --from=builder /app/target/aarch64-unknown-linux-musl/release/ecu_engine ./ecu_engine

# Command to run the executable
CMD ["./ecu_engine"]