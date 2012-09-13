{ exec } = require "child_process"
fs       = require "fs"
path     = require "path"

colors   = require "colors"
glob     = require "glob"
_        = require "underscore"

module.exports = class Bin
  constructor: (options={}) ->

    args     = process.argv.splice(2)
    names    = []
    branches = []
    skip     = false

    _.each args, (arg, index) ->
      if skip
        skip = false
        return

      if arg == '-b'
        branches.push(args[index + 1])
        skip = true
      else
        names.push(arg)


    if names.length
      
      ask = options.ask || @ask

      ask "What is your Github username?", (login) =>
        _.each names, (name) =>

          commands = []
          dir = null

          if name.indexOf('/') > -1
            dir = path.dirname(name)
            name = path.basename(name)

          if dir
            commands = commands.concat [
              "mkdir -p #{dir}"
              "cd #{dir}"
            ]

          commands = commands.concat [
            "git clone git://github.com/winton/node-template.git #{name}"
            "cd #{name}"
            "git remote rename origin node-template"
            "git fetch node-template"
            "git remote add origin git@github.com:#{login}/#{name}.git"
          ]

          if branches.length
            commands = commands.concat _.map branches.sort(), (branch) ->
              "git merge node-template/#{branch}"

          commands = commands.concat [
            "rm npm-shrinkwrap.json"
            "rm bin/node-template.coffee"
            "rm test/node-template.coffee"
          ]

          @executing(commands)
          
          exec commands.join(' && '), @catchError =>

            dir      = if dir then "#{dir}/" else ""
            commands = []
            cwd      = process.cwd()

            glob "#{dir}#{name}/**/node-template*", (e, paths) =>
              _.each paths, (path) ->
                commands.push "mv #{path} #{Bin.renamePath(path, name)}"

              @executing(commands)

              exec commands.join(' && '), @catchError =>

                commands = [ "cd #{dir}#{name}" ]

                # Overwrite files to remove node-template code

                overwrite = {}

                overwrite["bin/#{name}"] =
                  """
                  #!/usr/bin/env node

                  require("../lib/#{name}");
                  """

                overwrite["src/#{name}.coffee"] =
                  """
                  common = require './#{name}/common'
                  async  = common.async
                  _  = common.underscore
                  """
              
                _.each overwrite, (body, path) ->
                  if fs.existsSync("#{dir}#{name}/#{path}")
                    body = body.replace(/\n/g, "\\n").replace(/"/g, "\\\"")
                    commands.push "echo \"#{body}\" > #{path}"

                if fs.existsSync("#{dir}#{name}/src")
                  commands.push("coffee -o lib -c src")

                commands = commands.concat [
                  "cake install"
                  "cd #{cwd}"
                ]

                @executing(commands)
                
                exec commands.join(' && '), ->
                  if options.done then options.done() else process.exit()

  ask: (q, fn) ->
    console.log "\n#{q}".bold.yellow
    process.stdin.resume()
    process.stdin.setEncoding "utf8"
    process.stdin.on "data", (path) ->
      fn path.replace(/\s+$/, "")

  catchError: (successFn) ->
    (error, stdout, stderr) ->
      if error
        console.log "\nError :(".bold.red
        console.log error
        console.log stdout
        console.log stderr
      else
        console.log "\nSuccess :)\n".bold.green
        successFn(error, stdout, stderr) if successFn

  executing: (commands) ->
    console.log "\nExecuting:".bold.yellow
    _.each commands, (command) -> console.log(command)

  @renamePath: (p, new_name) ->
    base = path.basename(p)
    dir = path.dirname(p)
    "#{dir}/#{base.replace('node-template', new_name)}"