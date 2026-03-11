# Velero

Helm chart bundling [vmware-tanzu/velero](https://github.com/vmware-tanzu/velero) for Kubernetes backup and disaster recovery.

## Overview

Velero provides backup, restore, and disaster recovery capabilities for Kubernetes clusters. This wrapper chart configures Velero with sensible defaults for Chorus environments.

## Architecture

- **Velero Server**: Manages backup/restore operations, watches for schedules
- **Node Agent (Restic)**: File-level backup of Persistent Volumes on each node
- **Object Storage**: S3-compatible backend for storing backups (AWS S3, MinIO, etc.)

## Prerequisites

1. **Object Storage Bucket**: S3-compatible storage (AWS S3, MinIO, GCS, Azure Blob)
2. **Credentials**: Access keys or IAM role for storage access
3. **Velero CLI**: `brew install velero` (for operations)
4. **Kubernetes Access**: kubectl configured with admin permissions

## Mandatory Secrets

### Credentials

You can change the secret name in the Helm chart values.
Default is velero-credentials.

```bash
# Create credentials file
cat > credentials-velero <<EOF
[default]
aws_access_key_id=YOUR_ACCESS_KEY
aws_secret_access_key=YOUR_SECRET_KEY
EOF

# Create Kubernetes secret
kubectl create secret generic velero-credentials \
  --from-file=cloud=credentials-velero \
  --namespace velero

# Clean up local file
rm credentials-velero
```

## Configuration

### Backup Schedules

Schedules are defined per environment in `environments/{env}/velero/values.yaml`:

## Resources

- [Velero Documentation](https://velero.io/docs/)
- [Velero GitHub](https://github.com/vmware-tanzu/velero)
- [Backup Strategies](https://velero.io/docs/main/backup-reference/)
- [Disaster Recovery](https://velero.io/docs/main/disaster-case/)
