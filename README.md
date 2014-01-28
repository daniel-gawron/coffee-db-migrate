##Migrate

Abstract migration framework for node (in coffeescript) which store migration steps in db.

###Origin

This project is based on [cofee-migrate](https://github.com/winton/coffee-migrate).

The main difference:
	it stores migrated files titles in db

###Usage

```
Usage: migrate [options] [command]

Options:

   -c, --chdir <path>   change the working directory, --db store migration steps in db

Commands:

   down             migrate down
   up               migrate up (the default command)
   create [title]   create a new migration file with optional [title]

```
