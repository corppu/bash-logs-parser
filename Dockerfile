FROM ubuntu:22.04

# Install required tools
RUN apt-get update && apt-get install -y \
    bash \
    grep \
    zip \
    unzip \
    coreutils \
    findutils \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the script
COPY move-pattern-matching-logs.sh /app/
RUN chmod +x /app/move-pattern-matching-logs.sh

# Create test directory
RUN mkdir -p /test-data

# Set entrypoint
ENTRYPOINT ["/app/move-pattern-matching-logs.sh"]
