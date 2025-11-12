require 'rails_helper'

RSpec.describe MarkdownHelper, type: :helper do
	describe '#markdown_to_html' do
		it 'returns empty string for blank or nil input' do
			expect(helper.markdown_to_html(nil)).to eq("")
			expect(helper.markdown_to_html("")).to eq("")
		end

		it 'removes Subject: lines' do
			input = "Subject: Hello\nThis is the body"
			html = helper.markdown_to_html(input)
			expect(html).to include('<p>This is the body</p>')
			expect(html).not_to match(/Subject:/)
		end

		it 'converts inline markdown to html (links, code, bold, italic, strikethrough)' do
			input = "This is **bold**, *italic*, ~~strike~~, `code`, [link](http://example.com)"
			html = helper.markdown_to_html(input)

			expect(html).to include('<strong>bold</strong>')
			expect(html).to include('<em>italic</em>')
			expect(html).to include('<del>strike</del>')
			expect(html).to include('<code>code</code>')
			expect(html).to include('<a href="http://example.com">link</a>')
		end

		it 'handles blockquotes' do
			input = "> This is a quote"
			html = helper.markdown_to_html(input)

			expect(html.strip).to eq('<blockquote>This is a quote</blockquote>')
		end

		it 'aggregates paragraph lines and respects empty lines as separators' do
			input = "Line one\nLine two\n\nNext paragraph"
			html = helper.markdown_to_html(input)

			expect(html).to include('<p>Line one Line two</p>')
			expect(html).to include('<p>Next paragraph</p>')
		end

		it 'builds unordered lists and closes them correctly when followed by paragraph' do
			input = "- item1\n- item2\n\nAfter list"
			html = helper.markdown_to_html(input)
			expected = "<ul>\n<li>item1</li>\n<li>item2</li>\n</ul>\n<p>After list</p>"

			expect(html).to include("<ul>")
			expect(html).to include("<li>item1</li>")
			expect(html).to include("<li>item2</li>")
			expect(html).to include('<p>After list</p>')
			expect(html).to match(/<ul>\n<li>item1<\/li>\n<li>item2<\/li>\n<\/ul>\n<p>After list<\/p>/)
		end

		it 'closes list at EOF when no trailing blank line' do
			input = "- a\n- b"
			html = helper.markdown_to_html(input)

			expect(html).to match(/<ul>\n<li>a<\/li>\n<li>b<\/li>\n<\/ul>/)
		end

		it 'does not treat **bold** as italic (edge case for italic regex)' do
			input = "**bold** and *italic*"
			html = helper.markdown_to_html(input)

			expect(html).to include('<strong>bold</strong>')
			expect(html).to include('<em>italic</em>')
		end

		it 'processes accumulated paragraph before a blockquote' do
			input = "Intro line\n> A quote"
			html = helper.markdown_to_html(input)

			expect(html).to match(/<p>Intro line<\/p>\n<blockquote>A quote<\/blockquote>/)
		end

		it 'closes an open list when a blockquote appears' do
			input = "- item1\n> quoted"
			html = helper.markdown_to_html(input)

			expect(html).to match(/<ul>\n<li>item1<\/li>\n<\/ul>\n<blockquote>quoted<\/blockquote>/)
		end

		it 'processes accumulated paragraph before starting a list' do
			input = "Paragraph line\n- first\n- second"
			html = helper.markdown_to_html(input)

			expect(html).to match(/<p>Paragraph line<\/p>\n<ul>\n<li>first<\/li>\n<li>second<\/li>\n<\/ul>/)
		end

		it 'closes an open list when followed immediately by a non-list line (no blank line)' do
			input = "- item1\nNext is a paragraph"
			html = helper.markdown_to_html(input)

			expect(html).to match(/<ul>\n<li>item1<\/li>\n<\/ul>\n<p>Next is a paragraph<\/p>/)
		end
	end

	describe '#markdown_to_text' do
		it 'returns empty string for blank or nil input' do
			expect(helper.markdown_to_text(nil)).to eq("")
			expect(helper.markdown_to_text("")).to eq("")
		end

		it 'removes Subject: lines and strips markdown leaving plain text' do
			input = <<~MD
				Subject: Hello
				This is **bold** and *italic* with `code` and [link](http://example.com)
				> quoted
				- bullet


			MD

			text = helper.markdown_to_text(input)

			expect(text).to eq("This is bold and italic with code and link\nquoted\nbullet")
			expect(text).not_to match(/Subject:/)
			expect(text).not_to include('*')
			expect(text).not_to include('`')
			expect(text).not_to include('[')
		end

		it 'removes HTML tags if present and collapses multiple blank lines' do
			input = "<p>Some <strong>HTML</strong></p>\n\n\nEnd"
			text = helper.markdown_to_text(input)

			expect(text.split("\n")).to eq(['Some HTML', '', 'End'])
		end
	end
end
