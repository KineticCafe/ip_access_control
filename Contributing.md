# Contributing

We value any contribution to IpAccessControl you can provide: a bug
report, a feature request, or code contributions. Here are our guidelines for
contributions:

- Changes _will not_ be accepted without tests.
- Match our coding style; we use [Credo][] and `mix format`.
- Use a thoughtfully named topic branch that contains your change. Rebase
  your commits into logical chunks as necessary.
- Use [quality commit messages][].
- Do not change the version number; when your patch is accepted and a release
  is made, the version will be updated at that point.
- Submit a GitHub pull request with your changes.

## Workflow

Here's the most direct way to get your work merged into the project:

- Fork the project.
- Clone down your fork (`git clone git://github.com/<username>/ip_access_control.git`).
- Create a topic branch to contain your change (`git checkout -b my_awesome_feature`).
- Hack away, add tests. Not necessarily in that order.
- Make sure everything still passes with `mix test`.
- Make sure the code is clean with `mix credo --strict`.
- Make sure the code is clean with `mix credo --strict`.
- If necessary, rebase your commits into logical chunks, without errors.
- Push the branch up (`git push origin my_awesome_feature`).
- Create a pull request against KineticCafe/ip_access_controland
  describe your change does and the why you think it should be merged.

## Developer Certificate of Origin

All contributors **must** certify they are able and willing to provide their
contributions under the terms of this project's licenses with the certification
of the [Developer Certificate of Origin (Version 1.1)][dco].

Such certification is provided by ensuring that the following line must be
included as the last line of a commit message for every commit contributed:

    Signed-off-by: FirstName LastName <email@example.org>

The `Signed-off-by` line can be automatically added by git with the `-s` or
`--signoff` option on `git commit`:

```sh
git commit --signoff
```

## Contributors

- Austin Ziegler created `ip_access_control`, based in part on
  [`plug_ip_whitelist`][] by Forward Financing.

[quality commit messages]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[credo]: https://github.com/rrrene/credo
[`plug_ip_whitelist`]: https://github.com/ForwardFinancing/plug_ip_whitelist
[dco]: https://developercertificate.org
