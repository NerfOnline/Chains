# Building a Chains release

From the repository root:

```sh
bash scripts/build-release.sh
```

The script runs in bash. macOS and Linux include it. The GitHub `gh` command is used only if you confirm the release, and it needs to be logged in to the repository.

The script asks for two things first:

1. Version, such as `0.92c`.
2. `Release` or `Pre-release`.

It writes that pair into `addon.version` in `chains/chains.lua`. It does not read the old version from the file, and it does not commit the change.

It then builds three zips in `dist/`. Each zip contains only `chains/chains.lua`, `chains/skills.lua`, and `chains/pets.lua`. All three share the same `chains.lua` and `pets.lua`. Each `skills.lua` is rendered from that server's data file.

For version `0.92c` and Pre-release the files are:

- `dist/Chains-v0.92c-Pre-release.zip` (Retail)
- `dist/Chains-v0.92c-Pre-release-Horizon.zip`
- `dist/Chains-v0.92c-Pre-release-Phoenix.zip`

Retail omits the server name. Horizon and Phoenix are added after the channel.

After the zips exist, the script asks for the GitHub release title, tag, and message. It prints those values and the three zip paths, then asks you to confirm before submitting. Answering anything other than `y` leaves the zips in `dist/` and does not create a release. A Pre-release is posted as a GitHub pre-release.

`dist/` is gitignored. The skillchain database is split by server:

- `scripts/skills-data.lua` (Retail)
- `scripts/skills-data-horizon.lua`
- `scripts/skills-data-phoenix.lua`
