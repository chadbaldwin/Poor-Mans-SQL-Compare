# Poor Mans SQL Compare

I created this powershell script years ago as a free replacement for SQL Compare. At the time, I didn't have access to a SQL Compare license and my company at the time, was not purchasing any more. So I had to come up with some sort of solution to freely compare a large number of databases across various servers, and this was my solution.

The script takes a JSON settings file. The file contains things like which servers you want to run on, which databases you want to exclude, and your server mappings.

I could have written the script to just generate a cartesian product of server mappings, but that seemed ridiculous, especially if you have a lot of servers, so instead, it's manual.

For example, if your environment looks like this: `Development -> Testing -> Production`, then you would probably want a mapping between `Development -> Testing` as well as `Testing -> Production`.

This way you can compare and see what changes need to go out in the order of your deployment flow.

You may also want to have one from `Production -> Development`. If you don't have automated restores set up for your development environment, it may help you maintain a clean development environment.

## Dependencies/Notes

* PowerShell Core 7
  * This script was written with the intention it be run within a PS Core 7 shell. I have not tested it on other shells, as I don't expect many other people to be using this than me.
* [dbatools PowerShell module](https://dbatools.io/)
  * This is needed to obtain the list of databases from the server as well as their replica states if you are using HA. There's no point in comparing a replicated database if we know they are the same.
* Windows Authentication
  * This script defaults to using Windows Authentication. As of now, I have no plans to expand it to use other authentication methods, but it wouldn't be too hard to do it yourself.
* Permission to access `sys` objects on each of the configured servers

## Usage

First configure the settings file, which looks like this:

```json
{
  "servers": ["DEV","TEST","PROD"],
  "excludes": ["DBFoo", "DBBar"],
  "groups": [
    {"source":"DEV", "dest":"TEST"},
    {"source":"TEST", "dest":"PROD"},
  ]
}
```

* Servers - List of servers you want to run this against. The identifiers specified here would be similar to whatever you type into SSMS to connect to a server.
* Excludes - List of databases you want to exclude. By default, it excludes system databases, these excludes append to that list. For example, you might have a scratch database that's just used for temporary files, temporary backups, etc that you don't care about comparing.
* Groups - List of server mappings. `source` is the "from" server, and `dest` is the "to". For example, you want to compare `DEV` to `TEST` with the intention of deploy to `TEST`.

All of the magic is in `GenerateFiles.ps1`. It has 1 parameter, which is `-SettingsFilePath`.

Simply run the script with the supplied settings file path. The script will reach out to each server in parallel, grab a list of all databases that are not replicated, and then generate a file for each database pair.

So if you configured servers `DEV`, `TEST`, `PROD`, and each server has two databases `DBFoo` and `DBBar`. You will end up with 4 files:

```plaintext
DEV_TEST.DBFoo.scmp
DEV_TEST.DBBar.scmp
TEST_PROD.DBFoo.scmp
TEST_PROD.DBBar.scmp
```

These files can be opened up in Visual Studio and the comparison can be run.

THere are some settings I've set in the template .scmp file. You can change these if you want, but you need to make sure you retain the replacement values like `%%SOURCE_SERVER%%` and similar. You could probalby do this pretty easily if you use a diff tool. Make your changes to one of the generated files, then diff your changed file with the `FROM_TO.DATABASE.scmp` file, and only apply the changes you want.
