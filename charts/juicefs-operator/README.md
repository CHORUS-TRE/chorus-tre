# JuiceFS Operator Helm Chart

Wraps the upstream [`juicedata/juicefs-operator`](https://github.com/juicedata/juicefs-operator) and
adds an off-site **backup** of the JuiceFS data bucket via a scheduled `CronSync`, plus the CHORUS
network policies. This README covers how the backup works, the secrets it needs, and how to verify,
browse, and restore from it.

## How the backup works

JuiceFS stores file **data** as chunks in an S3 bucket and the **metadata** (the file tree) in a
separate engine (Redis/Valkey). A backup therefore has two substrates, and both live in the bucket:

- **Chunks** — the file data blocks.
- **`meta/` dumps** — JuiceFS auto-backs-up the metadata to the *source* bucket's `meta/` prefix
  hourly (`--backup-meta`), producing `meta/dump-<timestamp>.json.gz` snapshots.

This chart deploys a `CronSync` (`juicefs-data-replica`) that runs `juicefs sync` on a schedule,
copying the **whole source bucket (chunks + `meta/` dumps)** to a dedicated **replica bucket**:

- **Append-only** — `--ignore-existing`, never `--delete`. The replica only ever grows, so a
  source-side wipe or key compromise cannot propagate to the backup, and every metadata dump on the
  replica stays fully restorable (all the chunks it references are guaranteed still present).
- **First run** copies everything; subsequent runs are incremental (existing objects are skipped).
- **RPO** ≈ sync cadence + metadata cadence (e.g. daily sync + hourly metadata ≈ 25h worst case).
  Lower the `cronSync.schedule` interval to tighten it.

> The replica is a byte-for-byte copy. If the JuiceFS volume uses **client-side encryption** (an RSA
> key at format time), the replica chunks are ciphertext and restore additionally requires the source
> RSA private key + passphrase — **escrow it out-of-band**, the replica is useless without it. If the
> volume is unencrypted, no key is needed.

## Configuration

```yaml
cronSync:
  enabled: true
  schedule: "0 4 * * *"            # daily; align after the metadata auto-backup window
  image: juicedata/juicefs:1.3.1   # any image carrying the juicefs binary (incl. `sync`)
  imagePullSecrets: []             # e.g. [{name: <pull-secret>}] when pulling from a private/proxy registry
  source:
    host: <s3-endpoint>            # e.g. s3.example.com (no scheme)
    bucket: <source-bucket>
    secretName: juicefs-secret     # keys: access-key, secret-key
  replica:
    host: <s3-endpoint>
    bucket: <replica-bucket>       # dedicated bucket, separate from the source
    secretName: juicefs-sync-replica
chorusNetworkPolicy:
  enabled: true
  enabled_l7_waf: false            # true -> CiliumNetworkPolicy, false -> NetworkPolicy
```

The sync URI is built path-style as `s3://<host>/<bucket>` for both source and replica.

## Mandatory Secrets

Both credential secrets live in the release namespace and carry the keys `access-key` and
`secret-key`. Names are configurable via `cronSync.source.secretName` / `cronSync.replica.secretName`.

### Source bucket credentials (`juicefs-secret`)

Read access to the source JuiceFS bucket. This is usually the **same S3 key the JuiceFS CSI driver
already uses**, so rather than duplicating it you can mirror it into this namespace (e.g. with
kubernetes-reflector). The CSI secret typically also carries `bucket`, `metaurl`, `name`, `storage` —
harmless for the sync, and the `metaurl` key is needed later for browsing (see below).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: juicefs-secret
  namespace: <namespace>
stringData:
  access-key: "<s3-access-key>"
  secret-key: "<s3-secret-key>"
type: Opaque
```

### Replica bucket credentials (`juicefs-sync-replica`)

Read/write on the replica bucket. Prefer a **dedicated key scoped to the replica bucket** (separate
revocation surface from the live-mount key). Create the replica bucket out-of-band first.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: juicefs-sync-replica
  namespace: <namespace>
stringData:
  access-key: "<replica-s3-access-key>"
  secret-key: "<replica-s3-secret-key>"
type: Opaque
```

### (Optional) Image pull secret

If the sync image is pulled from a private or pull-through registry (rather than public Docker Hub),
create the pull secret in the namespace and reference it:

```yaml
cronSync:
  image: <registry>/juicedata/juicefs:1.3.1
  imagePullSecrets:
    - name: <pull-secret>
```

## Verifying the backup

Watch a run and confirm it finished cleanly (`copied == found`, `failed: 0`):

```
kubectl logs -n <namespace> \
  -l app.kubernetes.io/managed-by=juicefs-operator --tail=50 -f
```

Cross-check object count/size on source vs replica, and confirm metadata dumps rode along
(`mc` = the MinIO client):

```
mc alias set src https://<s3-endpoint> <source-access-key> <source-secret-key>
mc alias set rep https://<s3-endpoint> <replica-access-key> <replica-secret-key>
mc du  src/<source-bucket>
mc du  rep/<replica-bucket>
mc ls  rep/<replica-bucket>/meta/
```

Roughly matching totals + a fresh `meta/dump-*.json.gz` = the backup is good.

## Browsing the backup (read-only)

Chunks are opaque, so to see actual files you reconstruct the filesystem from metadata and mount it
read-only against the **replica** bucket. The pod below dumps the **live source metadata**
(read-only), loads it into a throwaway local SQLite DB, repoints that copy at the replica bucket, and
mounts it read-only at `/mnt/backup`. It **modifies nothing**: the source metadata is only read; the
replica bucket is only read (`config --force` skips its sanity-check write, `mount --read-only
--backup-meta 0` writes no chunks and no metadata dumps).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: jfs-restore-browse
  namespace: <namespace>
spec:
  restartPolicy: Never
  imagePullSecrets:
    - name: <pull-secret>          # only if the image needs it
  containers:
    - name: juicefs
      image: <juicefs-image>       # any image with the juicefs binary
      securityContext:
        privileged: true           # FUSE mount
      env:
        - name: SRC_METAURL        # source metadata engine URL (the CSI juicefs-secret 'metaurl' key)
          valueFrom: { secretKeyRef: { name: juicefs-secret, key: metaurl } }
        - name: AK
          valueFrom: { secretKeyRef: { name: juicefs-sync-replica, key: access-key } }
        - name: SK
          valueFrom: { secretKeyRef: { name: juicefs-sync-replica, key: secret-key } }
      command: ["sh", "-c"]
      args:
        - |
          set -e
          juicefs dump "$SRC_METAURL" /tmp/dump.json.gz
          juicefs load 'sqlite3:///tmp/meta.db' /tmp/dump.json.gz
          juicefs config 'sqlite3:///tmp/meta.db' --storage s3 \
            --bucket https://<s3-endpoint>/<replica-bucket> \
            --access-key "$AK" --secret-key "$SK" --force
          mkdir -p /mnt/backup
          juicefs mount 'sqlite3:///tmp/meta.db' /mnt/backup --read-only --backup-meta 0 -d
          sleep 3 && ls -la /mnt/backup
          sleep infinity
```

```
kubectl apply -f jfs-restore-browse.yaml
kubectl logs -n <namespace> jfs-restore-browse -f          # wait until it lists /mnt/backup
kubectl exec -it -n <namespace> jfs-restore-browse -- ls -la /mnt/backup
kubectl exec -it -n <namespace> jfs-restore-browse -- sh   # browse /mnt/backup
kubectl delete pod -n <namespace> jfs-restore-browse       # tear down when done
```

Notes:
- The **bucket URL is path-style** (`https://<s3-endpoint>/<bucket>`); match the source's format or
  the storage test will fail.
- FUSE needs `privileged` (or `SYS_ADMIN` + `/dev/fuse`); if PodSecurity blocks it, run where the CSI
  mount pods are allowed.

## Recovering a single file

With the browse pod mounted, copy the file straight off the read-only mount:

```
kubectl cp -n <namespace> \
  jfs-restore-browse:/mnt/backup/<path/to/file> ./<file>
```

If `kubectl cp` reports `tar: not found`, stream it instead (**no `-t`** — a TTY corrupts binary):

```
kubectl exec -n <namespace> jfs-restore-browse -- \
  cat /mnt/backup/<path/to/file> > ./<file>
```

A successful read pulls the file's chunks from the replica, so it also proves those chunks are intact.

## Disaster recovery (whole filesystem)

Bring up a JuiceFS filesystem backed by the replica bucket. Load a metadata snapshot into a metadata
engine, repoint its storage at the replica, and mount.

### If the source metadata engine is still available

Use a fresh dump of the live source metadata:

```
juicefs dump <source-metaurl> /tmp/dump.json.gz
juicefs load <new-metaurl> /tmp/dump.json.gz
juicefs config <new-metaurl> --storage s3 \
  --bucket https://<s3-endpoint>/<replica-bucket> \
  --access-key <replica-access-key> --secret-key <replica-secret-key> --force
juicefs mount <new-metaurl> /mnt/restore          # add --read-only to inspect first
```

### If the source metadata engine is also lost (true DR)

Use the metadata dump that the backup itself carries, so recovery is fully independent of the source:

```
mc cp rep/<replica-bucket>/meta/<latest-dump>.json.gz /tmp/dump.json.gz
juicefs load <new-metaurl> /tmp/dump.json.gz
juicefs config <new-metaurl> --storage s3 \
  --bucket https://<s3-endpoint>/<replica-bucket> \
  --access-key <replica-access-key> --secret-key <replica-secret-key> --force
juicefs mount <new-metaurl> /mnt/restore
```

`<new-metaurl>` is any metadata engine you stand up for recovery (e.g. a throwaway Redis/Valkey, or
`sqlite3:///path/meta.db` for a local/read-only inspection). To promote the recovered data back to a
primary, either point production at it or `juicefs sync` it into a fresh primary bucket.

## Read-only safety

When inspecting the backup, keep it strictly read-only so a mistake can't touch the only copy:

- `juicefs mount --read-only --backup-meta 0` — no chunk writes and no metadata dumps written to the bucket.
- `juicefs config --force` — skips the storage sanity-check, which otherwise **writes** a test object.
- Best of all, use a **read-only S3 key** for the replica so writes are impossible at the IAM level.
