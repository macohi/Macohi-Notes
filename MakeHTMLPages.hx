import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class MakeHTMLPage {
	static var blacklistedPages:Array<String> = ['./.obsidian', './.git', './filesize', './Templates'];

	static var reads:Map<String, Array<String>> = [];

	static function readDir(dir:String, f:String->Void) {
		var dirList:Array<String> = FileSystem.readDirectory(dir);

		var read:Array<String> = [];

		for (dirEnt in dirList) {
			final path = '$dir/$dirEnt';

			if (FileSystem.isDirectory(path)) {
				if (blacklistedPages.contains(path)) {
					trace('Blacklisted page: $path');
					continue;
				}

				FileSystem.createDirectory('./filesize${path.substr(1)}');
				readDir(path, f);
			} else {
				read.push(path);

				if (f != null)
					f(path);
			}
		}

		if (read.length > 0)
			reads.set(dir, read);
	}

	static function main() {
		readDir('.', function(f) {
			if (Path.extension(f) == 'md') {

				Sys.command('haxe', [
					'--interp',
					'--main MarkdownToHtml',
					f,
					'./filesize${Path.withoutExtension(f.substr(1))}.html',
				]);
			}
		});

		trace('Directories:');
		for (dir => paths in reads) {
			trace(' * $dir (${paths.length} items)');
		}
	}
}
