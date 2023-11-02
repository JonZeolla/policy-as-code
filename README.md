# Policy as Code Lab

## Getting Started

First, configure the IP variable with your public IP - to find it, [go here](https://ipv4.icanhazip.com/).

```bash
export CLIENT_IP=X.X.X.X # TODO: Replace this with your IP
```

Now, run the lab setup container.

```bash
docker run -e C9_PROJECT -e CLIENT_IP -e HOST_USER="${USER}" --network host -v ~/logs:/root/logs -v ~/.ssh:/root/.ssh jonzeolla/labs:policy-as-code
```

## Customizing

If you need to pass custom arguments to the `ansible-playbook` command in the `entrypoint.sh`, pass in the arguments as an env var named `ANSIBLE_CUSTOM_ARGS`

## Updating

Standard updates are automated to run twice a week and open a PR if anything changes (via `task update`). If you need to rebase the branches of any related demo
repos (as defined under `hack/demo-repos.yml`) then run `task update-demo-repos`
