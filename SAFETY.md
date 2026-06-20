# AppLibraryEnabler Test Safety

This tweak has two file-based switches for SpringBoard testing.

Disable the tweak before SpringBoard initializes:

```sh
touch /var/mobile/Library/Preferences/com.tomaszpoliszuk.applibraryenabler.disable
sbreload
```

Re-enable it:

```sh
rm /var/mobile/Library/Preferences/com.tomaszpoliszuk.applibraryenabler.disable
sbreload
```

Enable optional runtime logs:

```sh
touch /var/mobile/Library/Preferences/com.tomaszpoliszuk.applibraryenabler.log
sbreload
```

Disable logs:

```sh
rm /var/mobile/Library/Preferences/com.tomaszpoliszuk.applibraryenabler.log
sbreload
```

Logs are emitted with the prefix:

```text
[AppLibraryEnabler]
```
