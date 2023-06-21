# MinIO

The following information related to installing and setting up MinIO was taken from https://min.io/docs/minio/container/index.html.

MinIO is an object storage solution that provides an Amazon Web Services S3-compatible API and supports all core S3 features. MinIO is built to deploy anywhere - public or private cloud, baremetal infrastructure, orchestrated environments, and edge infrastructure. More info at https://min.io/docs/minio/container/index.html



## Quickstart

This procedure deploys a Single-Node Single-Drive MinIO server onto Docker.

### Prerequisites

- Docker installed.
- Read, write, and delete access to the folder or drive used for the persistent volume.


### Procedure

**1.** Start the container:

```bash
mkdir -p ${HOME}/minio/data

docker run \
   -p 9000:9000 \
   -p 9090:9090 \
   --user $(id -u):$(id -g) \
   --name minio1 \
   -e "MINIO_ROOT_USER=ROOTUSER" \
   -e "MINIO_ROOT_PASSWORD=CHANGEME123" \
   -v ${HOME}/minio/data:/data \
   quay.io/minio/minio server /data --console-address ":9090"
```

The example above works this way:

- `mkdir` creates a new local directory at `~/minio/data` in your home directory.
- `docker run` starts the MinIO container.
- `-p` binds a local port to a container port.
- `-user` sets the username for the container to the policies for the current user and user group.
- `-name` creates a name for the container.
- `-v` sets a file path as a persistent volume location for the container to use. When MinIO writes data to `/data`, that data actually writes to the local path `~/minio/data` where it can persist between container restarts. You can replace `${HOME}/minio/data` with another location in the user’s home directory to which the user has read, write, and delete access.
- `-e` sets the environment variables `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`, respectively. These set the root user credentials. Change the example values to use for your container.


**2.** Connect your Browser to the MinIO Server

Access the MinIO Console by going to a browser and going to `http://127.0.0.1:9000` or one of the Console addresses specified in the `minio server` command’s output. For example, `Console: http://192.0.2.10:9090 http://127.0.0.1:9090` in the example output indicates two possible addresses to use for connecting to the Console.

While port `9000` is used for connecting to the API, MinIO automatically redirects browser access to the MinIO Console.

Log in to the Console with the credentials you defined in the `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` environment variables.



## Connect Kazoo to MinIO

**1.** Create a bucket via MinIO Console in the `Buckets` section.

**2.** Start Crossbar's `storage` HTTP API if not started, yet:
```bash
$ sup crossbar_maintenance start_module cb_storage
```

**3.** Create a JSON file with the content below. It includes the configuration to store call recordings within MinIO:
```json
{
  "data": {
    "attachments": {
      "b6fac6f8023e47f0be9a8fabb4da1a8d": {
        "handler": "s3",
        "name": "Call Recordings storage",
        "settings": {
          "bucket": "{BUCKET_NAME}",
          "host": "127.0.0.1",
          "key": "{MINIO_ROOT_USER}",
          "port": 9000,
          "secret": "{MINIO_ROOT_PASSWORD}",
          "scheme": "http"
        }
      }
    },
    "plan": {
      "modb": {
        "types": {
          "call_recording": {
              "attachments": {
                  "handler": "b6fac6f8023e47f0be9a8fabb4da1a8d"
              }
          }
        }
      }
    }
  }
}
```

`b6fac6f8023e47f0be9a8fabb4da1a8d` can be changed to any other 32 bits long UUID.

**4.** Configure Kazoo to use your MinIO server:
```bash
$ curl -vX \
    PUT localhost:8000/v2/accounts/{ACCOUNT_ID}/storage \
    -H "X-Auth-Token: $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d "@{JSON_CONFIG_FILE}" | python -m json.tool
```
