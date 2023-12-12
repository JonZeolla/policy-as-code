# Policy as Code Lab

## Getting Started

Run the lab setup container.

```bash
docker run -it --network host -v ~/logs:/root/logs -v ~/.ssh:/root/.ssh jonzeolla/labs:policy-as-code
```

You'll be prompted to provide your IP, and setup will continue automatically from there.

## Customizing

If you need to pass custom arguments to the `ansible-playbook` command in the `entrypoint.sh`, pass in the arguments as an env var named `ANSIBLE_CUSTOM_ARGS`.

You can also specify a custom user by setting the `HOST_USER` environment variable inside the container.

## Updating

Standard updates are automated to run twice a week and open a PR if anything changes (via `task update`). If you need to rebase the branches of any related demo
repos (as defined under `hack/demo-repos.yml`) then run `task update-demo-repos`
