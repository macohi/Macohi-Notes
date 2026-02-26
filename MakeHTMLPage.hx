import sys.FileSystem;

class MakeHTMLPage
{
	static var blacklistedPages:Array<String> = ['./.obsidian', './.git'];

	static var reads:Map<String, Array<String>> = [];

	static function readDir(dir:String, f:String->Void)
	{
		var dirList:Array<String> = FileSystem.readDirectory(dir);

		var read:Array<String> = [];

		for (dirEnt in dirList)
		{
			final path = '$dir/$dirEnt';

			if (FileSystem.isDirectory(path))
			{
				if (blacklistedPages.contains(path))
				{
					trace('Blacklisted page: $path');
					continue;
				}

				readDir(path, f);
			}
			else
			{
				read.push(path);

				if (f != null)
					f(path);
			}
		}

		if (read.length > 0)
			reads.set(dir, read);
	}

	static function main()
	{
		readDir('.', function(f)
		{
			// trace(f);
		});

		trace('Directories:');
		for (dir => paths in reads)
		{
			trace(' * $dir (${paths.length} items)');
		}
	}
}
