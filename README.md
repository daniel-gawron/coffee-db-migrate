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
For use db to store migration steps, dbMigration.coffee file should be created in migrations folder.
Following methods dbMigration file must have:


exports.lockMigrationProcess = ( next ) ->
	#check if migration is running otherwise lock
	next()

exports.releaseMigration = ( next ) ->
	#remove lock
	next()

exports.getStoredMigrations = ( next )->
	#get all stored migrations
	next()

exports.saveState = ( title , status , next ) ->
	#save migration
	next()

exports.removeMigration = ( title , next ) ->
	#remove when error or down
	next()
