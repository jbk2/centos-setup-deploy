# Static website over TLS

An example of deploying a static website on a custom domain on CentOS 8 or CentOS 8 Stream.

It demostrates:

- Serving HTTPS content with NGINX
- Setting up TLS certificates with Let's Encrypt
- Rootless administration
- Running firewalld
- Automatic system updates and certificates renewals

## Configuration

The following variables configure the provisioning and configuration steps:

| Variable | Meaning                                  |
|----------|------------------------------------------|
| `SERVER` | Virtual machine public IP |
| `SERVER_NAME` | Domain name (with correct DNS settings) |
| `EMAIL` | Email for Let's Encrypt registration |
| `SSH_KEY` | Path to the private SSH key |
| `SITE_USER` | Name for the user that will replace *root* for administration |

Edit the `settings.sh` file to change this settings.

I recommend adding the SSH key to the OpenSSH authentication agent with:

```bash
$ ssh-add $SSH_KEY
```

Don't forget to set up DNS records:

```
domain.com  A  $SERVER
*.domain.com  CNAME  domain.com
```

## Provisioning

Provisioning step requires a virtual server with SSH-key based authentication preconfigured for *root*.

To provision the server for the first time, run `setup.sh`:

```bash
$ ./setup.sh
```

## Deployment

Once the server is properly configured, you can deploy the static content from a local `./public` directory with the following `deploy.sh` script:

```bash
$ ./deploy.sh
```

## Tasks

### Administration

To connect to the server as *$SITE_USER* with `ssh`:

```bash
$ ./ssh.sh
```

### Un/locking root

Once we are done rerunning `setup.sh` with diffirent NGINX settings, we can lock *root*:

```bash
$ ./lock.sh
```

And unlock it later if necessary:

```bash
$ ./unlock.sh
```