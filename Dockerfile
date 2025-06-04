# ------------------------
# Build Stage
# ------------------------
FROM golang:1.22-alpine AS build-env

# (Only needed if you ever npm-install during build)
RUN apk add --no-cache nodejs npm git
    
WORKDIR /app
    
# Cache deps
COPY go.mod go.sum ./
RUN go mod download
    
# Clone the ai-gourmet-mcp repository and build the Node.js project
RUN git clone https://github.com/Nirhoshan/ai-gourmet-mcp.git /app/ai-gourmet-mcp \
 && cd /app/ai-gourmet-mcp/mcp-server-typescript \
 && npm install \
 && npm run build
    
# Create non-root user
RUN addgroup -g 10014 choreo \
 && adduser -D -H -u 10014 -G choreo choreouser
    
COPY . .
    
# Build the Go binary
RUN go build -o /go/bin/app ./cmd/proxy/main.go
    
# ------------------------
# Runtime Stage
# ------------------------
FROM alpine
    
# Create non-root user with home directory
RUN addgroup -g 10014 choreo \
 && adduser -D -u 10014 -G choreo choreouser \
 && mkdir -p /home/choreouser \
 && chown -R choreouser:choreo /home/choreouser
    
# Install Node.js/npm for running the Node.js project
RUN apk add --no-cache nodejs npm
    
# Set HOME and npm cache to use /tmp which is typically writable
ENV HOME=/home/choreouser \
    NPM_CONFIG_CACHE=/tmp/.npm
    
# Pre-create npm cache in /tmp (which is usually writable)
RUN mkdir -p /tmp/.npm/_cacache/tmp /tmp/.npm/_logs \
 && chmod -R 777 /tmp/.npm
    
# Copy in your Go binary and config
COPY --from=build-env /go/bin/app /go/bin/app
COPY config.yaml /home/choreouser/config.yaml
    
# Copy the built Node.js project to the user directory
COPY --from=build-env /app/ai-gourmet-mcp/mcp-server-typescript /home/choreouser/ai-gourmet-mcp/mcp-server-typescript

# Set proper ownership for the copied files
RUN chown -R choreouser:choreo /home/choreouser/ai-gourmet-mcp
    
# Expose, switch user, set working dir
EXPOSE 8080
USER 10014

WORKDIR /home/choreouser
    
# Launch
CMD ["/go/bin/app", "--demo"]
