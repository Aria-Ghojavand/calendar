# Configuration for Unicorn Service Deployment

## Binary Download Instructions

The Unicorn service binary is provided as part of the game event. You need to:

1. **Download the binary** from the link provided in the game event README
2. **Place it** at `docker/unicorn-service`
3. **Make it executable**: `chmod +x docker/unicorn-service`

### Example download commands:
```bash
# Replace URL with actual download link from game event
curl -o docker/unicorn-service https://example.com/path/to/unicorn-service
chmod +x docker/unicorn-service
```

## Binary Requirements

According to the technical details, the binary:
- Is a Go binary compiled from source
- Is x86 statically linked, unstripped ELF executable 
- Must not be altered (grounds for disqualification)
- Listens on TCP port 80 by default
- Requires configuration from AWS AppConfig
- Needs access to Redis, PostgreSQL, and EFS
- Has health check endpoint at root path (/)

## Application Configuration

The application expects configuration through AWS AppConfig with the following structure:

```json
{
  "database": {
    "host": "rds-endpoint",
    "port": 5432,
    "name": "unicorndb",
    "user": "unicorn",
    "sslMode": "require"
  },
  "redis": {
    "host": "redis-endpoint",
    "port": 6379
  },
  "server": {
    "port": 80,
    "host": "0.0.0.0"
  },
  "efs": {
    "fsPath": "/app-cache/"
  }
}
```

## Command Line Help

Run the binary with `--help` to see available options:
```bash
./unicorn-service --help
```