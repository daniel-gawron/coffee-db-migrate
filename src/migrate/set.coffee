for key, value of require('./common')
	eval("var #{key} = value;")

module.exports = Set = (migrate_path, storeInDB) ->
	@migrations = []
	@path       = migrate_path
	@pos        = 0
	@useDB      = storeInDB

	setup = "#{path.dirname(@path)}/setup.coffee"
	setup = path.resolve(setup)

	if fs.existsSync(setup)
		setup = require setup
		setup @

	dbManagerPath = "#{path.dirname(@path)}/dbManager.coffee"
	dbManagerPath = path.resolve(dbManagerPath)
	if fs.existsSync(dbManagerPath)
		@dbManager = require dbManagerPath
		@
	else if @useDB
		console.error "Use db is on but there is no dbManager file"
		process.exit 1

Set::__proto__ = EventEmitter::

positionOfMigration = (migrations, filename) ->
	i = 0

	while i < migrations.length
		return i  if migrations[i].title is filename
		++i

	-1

Set::save = (fn) ->
	self = this
	json = JSON.stringify(this)

	fs.writeFile @path, json, (err) ->
		self.emit "save"
		fn and fn(err)

Set::load = (fn) ->
	@emit "load"

	fs.readFile @path, "utf8", (err, json) ->
		return fn(err)  if err
		try
			fn null, JSON.parse(json)
		catch err
			fn err

Set::loadMigrations = (fn)->
	@dbManager.getStoredMigrations (err,coll) ->
		if err
			fn err, null
		else if coll?
			fn null, coll

Set::checkIfRunning = (fn)->
	@dbManager.lockMigrationProcess (err)->
		unless err
			fn()
		else
			console.error "Error when try to lock migration process: "+err
			process.exit 1

Set::down = (fn, migrationName) ->
	@migrate "down", fn, migrationName

Set::up = (fn, migrationName) ->
	@migrate "up", fn, migrationName

Set::migrate = (direction, fn, migrationName) ->
	self = this
	fn   = fn or ->

	if @useDB
		@checkIfRunning  ()=>
				self._migrate direction, fn, migrationName
	else
		@load (err, obj) ->
			if err
				return fn(err)  unless "ENOENT" is err.code
			else
				self.pos = obj.pos

			self._migrate direction, fn, migrationName

Set::_migrate = (direction, fn, migrationName) ->
	next = (err, migration) =>
		# error from previous migration
		if err
			if @useDB
				@dbManager.releaseMigration ()->
					console.error err
					return fn(err)
			else
				return fn(err)

		# done
		unless migration
			self.emit "complete"
			if @useDB
				@dbManager.releaseMigration ()=>
					self.emit "save"
				return
			else
				self.save fn
				return

		self.emit "migration", migration, direction

		migration[direction] (err) =>
			if @useDB
				if err || direction is "down"
					@dbManager.removeMigration migration.title, ()->
						next err, migrations.shift()
				else
					@dbManager.saveState migration.title,'done', (doneErr) ->
						if doneErr
							console.error doneErr
						next err, migrations.shift()
			else
				next err, migrations.shift()

	self         = this
	migrations   = undefined
	migrationPos = undefined
	if @useDB
		dbMigrations =undefined
		@loadMigrations (err,dbMigrations)=>
			if err
				console.error "Error when try to load migrations: "+ err
				@dbManager.releaseMigration ()=>
					self.emit "error"
			else
				migrations =[]
				switch direction
					when "up"
						_.each @migrations, (mig)->
							if !_.contains dbMigrations, mig.title
								migrations.push mig
					when "down"
						_.each @migrations, (mig)->
							if _.contains dbMigrations, mig.title
								migrations.push mig
				if migrationName
					migrationPos = positionOfMigration(migrations, migrationName)
					if migrationPos == -1
						if direction is "up"
							console.error "Could not find migration, or migration is allready migrated: " + migrationName
						else
							console.error "Could not find migration for revert in db: " + migrationName
						@dbManager.releaseMigration ()=>
							self.emit "error"
					else
						switch direction
							when "up"
								migrations = migrations.slice(0, migrationPos + 1)
							when "down"
								migrations = migrations.slice(migrationPos, migrations.length).reverse()
						next null, migrations.shift()
				else
					next null, migrations.shift()
	else
		unless migrationName
			migrationPos = (if direction is "up" then @migrations.length else 0)

		else if (migrationPos = positionOfMigration(@migrations, migrationName)) is -1
			console.error "Could not find migration: " + migrationName
			process.exit 1

		switch direction
			when "up"
				migrations = @migrations.slice(@pos, migrationPos + 1)
				@pos += migrations.length
			when "down"
				migrations = @migrations.slice(migrationPos, @pos).reverse()
				@pos -= migrations.length

		next null, migrations.shift()