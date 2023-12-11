# Policy as Code Lab

## Getting Started

Run the lab setup container.

```bash
docker run -it -e CLIENT_IP -e HOST_USER="${USER}" --network host -v ~/logs:/root/logs -v ~/.ssh:/root/.ssh jonzeolla/labs:policy-as-code
```

If you didn't already set a `CLIENT_IP` variable, you'll be prompted to provide your IP.

## Customizing

If you need to pass custom arguments to the `ansible-playbook` command in the `entrypoint.sh`, pass in the arguments as an env var named `ANSIBLE_CUSTOM_ARGS`

## Updating

Standard updates are automated to run twice a week and open a PR if anything changes (via `task update`). If you need to rebase the branches of any related demo
repos (as defined under `hack/demo-repos.yml`) then run `task update-demo-repos`
