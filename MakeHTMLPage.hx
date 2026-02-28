/**
 * MarkdownToHtml.hx
 * ------------------
 * A simple Haxe script that converts an Obsidian-style Markdown (.md) file
 * into a basic HTML (.html) file.
 *
 * Supported Markdown features:
 *  - Headings (# through ######)
 *  - Bold (**text**)
 *  - Italic (*text*)
 *  - Inline code (`code`)
 *  - Code blocks (``` fenced blocks)
 *  - Links [text](url)
 *  - Unordered lists (- item)
 *
 * Usage:
 *   haxe --main MarkdownToHtml --interp input.md output.html
 *
 * Or compile to another target (example for Neko):
 *   haxe -main MarkdownToHtml -neko convert.n
 *   neko convert.n input.md output.html
 */

import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import StringTools;

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
				MarkdownToHtml.convert(f, './filesize${Path.withoutExtension(f.substr(1))}.html');
			}
		});

		trace('Directories:');
		for (dir => paths in reads) {
			trace(' * $dir (${paths.length} items)');
		}

		// --- Generate index.html ---
		var index = new StringBuf();
		index.add("<!DOCTYPE html>\n");
		index.add("<html>\n<head>\n<meta charset=\"UTF-8\">\n");
		index.add("<title>Index</title>\n");
		index.add("<style>\n");
		index.add("body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; line-height: 1.6; }\n");
		index.add("ul { margin-bottom: 20px; }\n");
		index.add("</style>\n");
		index.add("</head>\n<body>\n");
		index.add("<h1>Index</h1>\n");

		for (dir => paths in reads) {
			var addedHeader = false;

			for (path in paths) {
				if (Path.extension(path) == "md") {
					// Only create section header if directory actually has markdown
					if (!addedHeader) {
						index.add("<h2>" + dir + "</h2>\n<ul>\n");
						addedHeader = true;
					}

					var name = Path.withoutExtension(path);

					// Match your conversion output structure
					var htmlPath = './filesize' + Path.withoutExtension(path.substr(1)) + '.html';

					index.add('<li><a href="' + htmlPath + '">' + name + '</a></li>\n');
				}
			}

			if (addedHeader) {
				index.add("</ul>\n");
			}
		}

		index.add("</body>\n</html>");

		File.saveContent("./index.html", index.toString());
		trace("Generated ./index.html");
	}
}

class MarkdownToHtml {
	public static function convert(inputPath:String, outputPath:String) {
		if (!FileSystem.exists(inputPath)) {
			trace("Error: Input file does not exist.");
			return;
		}

		// Read markdown file
		var markdown = File.getContent(inputPath);

		// Convert to HTML
		var htmlBody = convertMarkdown(markdown);

		// Wrap in basic HTML template
		var fullHtml = buildHtmlDocument(inputPath, htmlBody);

		// Write output file
		File.saveContent(outputPath, fullHtml);

		trace("Conversion complete: " + outputPath);
	}

	/**
	 * Converts Markdown text into HTML.
	 */
	static function convertMarkdown(markdown:String):String {
		var lines = markdown.split("\n");
		var html = new StringBuf();

		var inCodeBlock = false;
		var inList = false;

		for (line in lines) {
			var trimmed = StringTools.trim(line);

			// Handle fenced code blocks ```
			if (StringTools.startsWith(trimmed, "```")) {
				if (!inCodeBlock) {
					html.add("<pre><code>\n");
					inCodeBlock = true;
				} else {
					html.add("</code></pre>\n");
					inCodeBlock = false;
				}

				continue;
			}

			if (inCodeBlock) {
				html.add(escapeHtml(line) + "\n");
				continue;
			}

			// Headings (#, ##, ###, etc.)
			var headingLevel = 0;
			while (headingLevel < trimmed.length && trimmed.charAt(headingLevel) == "#") {
				headingLevel++;
			}

			if (headingLevel > 0 && headingLevel <= 6 && trimmed.charAt(headingLevel) == " ") {
				var content = trimmed.substr(headingLevel + 1);
				html.add('<h$headingLevel>' + parseInline(content) + '</h$headingLevel>\n');
				continue;
			}

			// Unordered list (- item)
			if (StringTools.startsWith(trimmed, "- ")) {
				if (!inList) {
					html.add("<ul>\n");
					inList = true;
				}

				var itemContent = trimmed.substr(2);
				html.add("<li>" + parseInline(itemContent) + "</li>\n");
				continue;
			} else if (inList) {
				html.add("</ul>\n");
				inList = false;
			}

			// Paragraph
			if (trimmed != "") {
				html.add("<p>" + parseInline(trimmed) + "</p>\n");
			}
		}

		// Close list if file ends while inside list
		if (inList) {
			html.add("</ul>\n");
		}

		return html.toString();
	}

	/**
	 * Converts inline Markdown elements (bold, italic, links, inline code).
	 */
	static function parseInline(text:String):String {
		// Escape HTML first
		text = escapeHtml(text);

		// Inline code `code`
		text = ~/`([^`]+)`/g.replace(text, "<code>$1</code>");

		// Bold **text**
		text = ~/\*\*(.*?)\*\*/g.replace(text, "<strong>$1</strong>");

		// Italic *text*
		text = ~/\*(.*?)\*/g.replace(text, "<em>$1</em>");

		// Links [text](url)
		text = ~/\[([^\]]+)\]\(([^)]+)\)/g.replace(text, function(r) {
			var label = r.matched(1);
			var url = r.matched(2);

			// If link points to a markdown file, convert to html
			if (StringTools.endsWith(url, ".md")) {
				url = url.substr(0, url.length - 3) + ".html";
			}

			return '<a href="' + url + '">' + label + '</a>';
		});

		return text;
	}

	/**
	 * Escapes HTML special characters to prevent breaking markup.
	 */
	static function escapeHtml(text:String):String {
		return text.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	}

	/**
	 * Wraps body content inside a minimal HTML document structure.
	 */
	static function buildHtmlDocument(file:String, body:String):String {
		return '<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>$file</title>
<style>
body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; line-height: 1.6; }
code { background: #f4f4f4; padding: 2px 4px; }
pre { background: #f4f4f4; padding: 10px; overflow-x: auto; }
</style>
</head>
<body>
'
			+ body
			+ '
</body>
</html>';
	}
}
