Feature: MarkdownHelper Edge Cases
  As a user
  I want markdown rendering to handle edge cases correctly
  So that emails are formatted correctly

  Background:
    Given authentication is enabled
    Given I am logged in

  Scenario: MarkdownHelper handles empty text
    When I convert markdown to HTML with text ""
    Then the result should be ""

  Scenario: MarkdownHelper handles nil text
    When I convert markdown to HTML with text nil
    Then the result should be ""

  Scenario: MarkdownHelper handles blank text
    When I convert markdown to HTML with text "   "
    Then the result should be ""

  Scenario: MarkdownHelper removes Subject line from markdown
    When I convert markdown to HTML with text:
      """
      Subject: Test Subject
      
      This is the body.
      """
    Then the result should not include "Subject: Test Subject"
    And the result should include "This is the body"

  Scenario: MarkdownHelper removes Subject line case-insensitively
    When I convert markdown to HTML with text:
      """
      subject: Test Subject
      
      This is the body.
      """
    Then the result should not include "subject: Test Subject"
    And the result should include "This is the body"

  Scenario: MarkdownHelper removes Subject line with whitespace
    When I convert markdown to HTML with text:
      """
      Subject:   Test Subject
      
      This is the body.
      """
    Then the result should not include "Subject:"
    And the result should include "This is the body"

  Scenario: MarkdownHelper handles multiple Subject lines
    When I convert markdown to HTML with text:
      """
      Subject: First Subject
      Subject: Second Subject
      
      This is the body.
      """
    Then the result should not include "Subject:"
    And the result should include "This is the body"

  Scenario: MarkdownHelper handles bold text
    When I convert markdown to HTML with text "**bold text**"
    Then the result should include "<strong>bold text</strong>"

  Scenario: MarkdownHelper handles italic text
    When I convert markdown to HTML with text "*italic text*"
    Then the result should include "<em>italic text</em>"

  Scenario: MarkdownHelper handles strikethrough text
    When I convert markdown to HTML with text "~~strikethrough text~~"
    Then the result should include "<del>strikethrough text</del>"

  Scenario: MarkdownHelper handles code text
    When I convert markdown to HTML with text "`code text`"
    Then the result should include "<code>code text</code>"

  Scenario: MarkdownHelper handles links
    When I convert markdown to HTML with text "[link text](https://example.com)"
    Then the result should include '<a href="https://example.com">link text</a>'

  Scenario: MarkdownHelper handles blockquotes
    When I convert markdown to HTML with text:
      """
      > This is a quote
      """
    Then the result should include "<blockquote>This is a quote</blockquote>"

  Scenario: MarkdownHelper handles bullet lists
    When I convert markdown to HTML with text:
      """
      - Item 1
      - Item 2
      """
    Then the result should include "<ul>"
    And the result should include "<li>Item 1</li>"
    And the result should include "<li>Item 2</li>"

  Scenario: MarkdownHelper handles asterisk bullet lists
    When I convert markdown to HTML with text:
      """
      * Item 1
      * Item 2
      """
    Then the result should include "<ul>"
    And the result should include "<li>Item 1</li>"
    And the result should include "<li>Item 2</li>"

  Scenario: MarkdownHelper handles paragraphs separated by empty lines
    When I convert markdown to HTML with text:
      """
      Paragraph 1
      
      Paragraph 2
      """
    Then the result should include "<p>Paragraph 1</p>"
    And the result should include "<p>Paragraph 2</p>"

  Scenario: MarkdownHelper handles nested formatting
    When I convert markdown to HTML with text "**bold *italic* text**"
    Then the result should include "<strong>"
    And the result should include "<em>italic</em>"

  Scenario: MarkdownHelper handles links before formatting
    When I convert markdown to HTML with text "[link](url) **bold**"
    Then the result should include '<a href="url">link</a>'
    And the result should include "<strong>bold</strong>"

  Scenario: MarkdownHelper handles code before formatting
    When I convert markdown to HTML with text "`code` **bold**"
    Then the result should include "<code>code</code>"
    And the result should include "<strong>bold</strong>"

  Scenario: MarkdownHelper handles bold before italic
    When I convert markdown to HTML with text "**bold** *italic*"
    Then the result should include "<strong>bold</strong>"
    And the result should include "<em>italic</em>"

  Scenario: MarkdownHelper handles lists with paragraphs
    When I convert markdown to HTML with text:
      """
      Paragraph before list
      
      - List item 1
      - List item 2
      
      Paragraph after list
      """
    Then the result should include "<p>Paragraph before list</p>"
    And the result should include "<ul>"
    And the result should include "<li>List item 1</li>"
    And the result should include "<li>List item 2</li>"
    And the result should include "<p>Paragraph after list</p>"

  Scenario: MarkdownHelper handles blockquotes with paragraphs
    When I convert markdown to HTML with text:
      """
      Paragraph before quote
      
      > Quote text
      
      Paragraph after quote
      """
    Then the result should include "<p>Paragraph before quote</p>"
    And the result should include "<blockquote>Quote text</blockquote>"
    And the result should include "<p>Paragraph after quote</p>"

  Scenario: MarkdownHelper handles markdown_to_text with empty text
    When I convert markdown to text with text ""
    Then the result should be ""

  Scenario: MarkdownHelper handles markdown_to_text with nil text
    When I convert markdown to text with text nil
    Then the result should be ""

  Scenario: MarkdownHelper handles markdown_to_text removing Subject line
    When I convert markdown to text with text:
      """
      Subject: Test Subject
      
      This is the body.
      """
    Then the result should not include "Subject: Test Subject"
    And the result should include "This is the body"

  Scenario: MarkdownHelper handles markdown_to_text removing HTML tags
    When I convert markdown to text with text "<p>HTML text</p>"
    Then the result should include "HTML text"
    And the result should not include "<p>"
    And the result should not include "</p>"

  Scenario: MarkdownHelper handles markdown_to_text removing formatting
    When I convert markdown to text with text "**bold** *italic* ~~strikethrough~~ `code`"
    Then the result should include "bold italic strikethrough code"
    And the result should not include "**"
    And the result should not include "*"
    And the result should not include "~~"
    And the result should not include "`"

  Scenario: MarkdownHelper handles markdown_to_text removing links
    When I convert markdown to text with text "[link text](https://example.com)"
    Then the result should include "link text"
    And the result should not include "https://example.com"
    And the result should not include "["
    And the result should not include "]"
    And the result should not include "("
    And the result should not include ")"

  Scenario: MarkdownHelper handles markdown_to_text removing blockquotes
    When I convert markdown to text with text:
      """
      > Quote text
      """
    Then the result should include "Quote text"
    And the result should not include ">"

  Scenario: MarkdownHelper handles markdown_to_text removing bullet points
    When I convert markdown to text with text:
      """
      - Item 1
      - Item 2
      """
    Then the result should include "Item 1"
    And the result should include "Item 2"
    And the result should not include "-"
    And the result should not include "*"

  Scenario: MarkdownHelper handles markdown_to_text cleaning up multiple blank lines
    When I convert markdown to text with text:
      """
      Paragraph 1
      
      
      
      Paragraph 2
      """
    Then the result should not include more than two consecutive newlines
    And the result should include "Paragraph 1"
    And the result should include "Paragraph 2"

  Scenario: MarkdownHelper handles markdown_to_text stripping whitespace
    When I convert markdown to text with text:
      """
      
      Text with whitespace
      
      """
    Then the result should be trimmed
    And the result should include "Text with whitespace"

  Scenario: MarkdownHelper handles complex markdown with all features
    When I convert markdown to HTML with text:
      """
      Subject: Complex Test
      
      **Bold text** and *italic text*
      
      - List item 1
      - List item 2
      
      > Blockquote text
      
      [Link text](https://example.com)
      
      `code text`
      """
    Then the result should not include "Subject:"
    And the result should include "<strong>Bold text</strong>"
    And the result should include "<em>italic text</em>"
    And the result should include "<ul>"
    And the result should include "<li>List item 1</li>"
    And the result should include "<li>List item 2</li>"
    And the result should include "<blockquote>Blockquote text</blockquote>"
    And the result should include '<a href="https://example.com">Link text</a>'
    And the result should include "<code>code text</code>"

