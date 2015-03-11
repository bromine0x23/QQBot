[TOC]

-------------------
# QQBot

## Requirements
- **Ruby** : 2.0.x or later.
- **yajl-ruby**
- **concurrent-ruby**
- **sqlite3**: required by some plugins.

## Usage

### Start:
``` shell
ruby main.rb
```

### Status:
```
login  #
logout #
relink #
```

### plugins:
```
plugin load   # load plugins
plugin unload # unload plugins
plugin reload # reload plugins
```

### Handler:
```
handle start # start handler
handle stop  # stop handler
```

## Issues
- Entities(friends, groups, ...) look up may get nil.