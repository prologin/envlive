# Dependencies
- Arch Linux

- Required packages:
  - sudo
  - syslinux
  - squashfs-tools
  - arch-install-scripts
  - gptfdisk
  - inkscape

- Required AUR packages:
  - pacaur

# Building the image

```sh
sudo ./build_envlive [--partmode {dos,gpt,dos_efi,gpt_mbr}] [--reset] [--builduser username] [--verbose] [--ignore light:big:full:aur] [--askpass] out.img [root_password]
```

For now, the Zeal documentation packages have to be inside the `docs/` folder for the build to succeed.
For testing purposes only, you can leave the folder empty.

A `logo.png` file is also required so that it can be used as a boot splash.

You can add new configuration files by adding them into `root_skel/etc/skel/`.

# How to

## Test Firefox profile

Copy `root_skel/etc/skel/.mozilla/firefox/default.prologin` to
`~/.mozilla/firefox/default.prologin`, then go to `about:profiles` and
create a new profile using this directory.

# TODO
- Contribute to Zeal so that it is able to download documentation from the command line.
- Add launchers for netbeans, eclipse, notepadqq, ...
