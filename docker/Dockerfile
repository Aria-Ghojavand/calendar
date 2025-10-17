# Dockerfile for Unicorn Service
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

# Install required packages
RUN yum update -y && \
    yum install -y \
    ca-certificates \
    curl \
    && yum clean all

# Create app user
RUN adduser -r -s /bin/false unicorn

# Create directories
RUN mkdir -p /app /app-cache && \
    chown unicorn:unicorn /app /app-cache && \
    chmod 755 /app /app-cache

# Copy the Go binary (to be provided by the event)
COPY unicorn-service /app/unicorn-service
RUN chmod +x /app/unicorn-service && \
    chown unicorn:unicorn /app/unicorn-service

# Switch to non-root user
USER unicorn

# Set working directory
WORKDIR /app

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

# Run the application
CMD ["./unicorn-service"]