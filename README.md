# Niconico Style Display

Read text from stdin and display it in niconico style.

## requirements
- gtk3

## usage

```
$ echo -e 'hello world\nhello world' | nsd.rb
$ journalctl -f -n 0 | nsd.rb
$ nsd.rb -jm <<EOF
"<span foreground=\"red\" size=\"x-large\">赤</span>\n<span foreground=\"blue\">青</span>\n<span foreground=\"yellow\" size=\"x-small\">黄</span>"
EOF
```
