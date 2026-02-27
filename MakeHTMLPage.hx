import haxe.PosInfos;
import haxe.xml.Access;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class MakeHTMLPage
{
	static var blacklistedPages:Array<String> = ['./.obsidian', './.git', './filesize', './Templates'];

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

				FileSystem.createDirectory('./filesize${path.substr(1)}');
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
			if (Path.extension(f) == 'md')
			{
				var f_html = convertMarkdownToHTML(f);

				File.saveContent('./filesize${Path.withoutExtension(f.substr(1))}.html', f_html);
			}
		});

		trace('Directories:');
		for (dir => paths in reads)
		{
			trace(' * $dir (${paths.length} items)');
		}
	}

	static function convertMarkdownToHTML(file:String):String
	{
		function log(v:Dynamic)
		{
			trace('CMTH($file) $v');
		}

		var markdown = File.getContent(file);
		var html = '';
		var html_body = [''];

		function makeElement(e:String)
			return '<$e>';

		function makeElementWithContent(e:String, c:String)
			return '${makeElement(e)}$c${makeElement('/$e')}';

		function addLine(line:String)
			html += '$line\n';

		function addElement(line:String)
			addLine(makeElement(line));

		function addElementGroup(element:String, inbetween:Array<String>)
		{
			addElement('$element');

			for (child in inbetween)
				addLine(child);

			addElement('/$element');
		}

		addLine('<!DOCTYPE html>');
		addLine('<html lang="en">');
		addElementGroup('head', [
			'<meta charset="UTF-8">',
			'<meta name="viewport" content="width=device-width, initial-scale=1.0">',
			makeElementWithContent('title', file),
		]);

		var properties:Bool = false;
		var hasProperties:Bool = false;
		var finishedProperties:Bool = false;
		var skipNext:Bool = false;

		for (i => thing in markdown.split('\n'))
		{
			if (skipNext)
			{
				skipNext = !skipNext;
				continue;
			}

			if (thing == '---' && !finishedProperties)
			{
				if (!hasProperties)
				{
					hasProperties = true;
					finishedProperties = false;
					properties = true;
				}
				else
				{
					finishedProperties = true;
					properties = false;
				}

				log('properties i: $i');
				continue;
			}

			if (properties)
				continue;

			// tags
			if (thing.startsWith('#'))
			{
				log('tag search: ' + i);

				if (i == 0 && !hasProperties)
					continue;
			}

			if (thing.trim().length == 0)
			{
				html_body.push(makeElement('br'));
				continue;
			}

			if (thing.startsWith('#'))
			{
				var headerType:Int = thing.lastIndexOf('#') + 1;
				var header = thing.substr(headerType);
				// log('headerType : $headerType');
				log('header : $header');

				if (!header.startsWith(' '))
					continue;

					html_body.push(makeElementWithContent('h$headerType', header.substr(1)));

				continue;
			}

			html_body.push(makeElementWithContent('p', thing));
		}
		html_body.push('');

		addElementGroup('body', html_body);

		addLine('</html');

		return html;
	}
}
