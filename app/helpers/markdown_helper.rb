module MarkdownHelper
  ##
  # Converts markdown to HTML
  # Supports: **bold**, *italic*, ~~strikethrough~~, `code`, [links](url), >quotes, bullet lists
  # Removes "Subject: ..." lines as subject is handled separately by mailer
  def markdown_to_html(text)
    return "" if text.blank?

    html = text.dup

    # Remove Subject line if present (subject is handled separately by CampaignMailer)
    html.gsub!(/^Subject:\s*.+$/i, '')

    # Split by lines to process block-level elements
    lines = html.split(/\n/)
    result = []
    in_list = false
    current_paragraph = []

    lines.each_with_index do |line, index|
      line_stripped = line.strip

      # Skip empty lines (they separate paragraphs)
      if line_stripped.empty?
        # If we have accumulated paragraph content, process it
        if current_paragraph.any?
          paragraph_text = current_paragraph.join(' ')
          result << "<p>#{process_inline_markdown(paragraph_text)}</p>"
          current_paragraph = []
        end
        # End list if we hit an empty line
        if in_list
          result << "</ul>"
          in_list = false
        end
        next
      end

      # Handle blockquotes
      if line_stripped.start_with?('>')
        # Process any accumulated paragraph first
        if current_paragraph.any?
          paragraph_text = current_paragraph.join(' ')
          result << "<p>#{process_inline_markdown(paragraph_text)}</p>"
          current_paragraph = []
        end
        result << "</ul>" if in_list
        in_list = false
        quote_text = line_stripped.sub(/^>\s*/, '')
        result << "<blockquote>#{process_inline_markdown(quote_text)}</blockquote>"
        next
      end

      # Handle bullet lists
      if line_stripped.match(/^[\-\*]\s+/)
        # Process any accumulated paragraph first
        if current_paragraph.any?
          paragraph_text = current_paragraph.join(' ')
          result << "<p>#{process_inline_markdown(paragraph_text)}</p>"
          current_paragraph = []
        end
        result << "<ul>" unless in_list
        in_list = true
        list_item = line_stripped.sub(/^[\-\*]\s+/, '')
        result << "<li>#{process_inline_markdown(list_item)}</li>"
        next
      end

      # End list if we hit a non-list line
      if in_list
        result << "</ul>"
        in_list = false
      end

      # Accumulate paragraph content (handle line breaks within paragraphs)
      current_paragraph << line_stripped
    end

    # Process any remaining paragraph content
    if current_paragraph.any?
      paragraph_text = current_paragraph.join(' ')
      result << "<p>#{process_inline_markdown(paragraph_text)}</p>"
    end

    # Close any open list
    result << "</ul>" if in_list

    result.join("\n").html_safe
  end

  private

  ##
  # Processes inline markdown formatting (bold, italic, links, code, strikethrough)
  def process_inline_markdown(text)
    html = text.dup

    # Convert links [text](url) - must come before other formatting
    html.gsub!(/\[([^\]]+)\]\(([^\)]+)\)/, '<a href="\2">\1</a>')

    # Convert code `text` - must come before bold/italic
    html.gsub!(/`([^`]+)`/, '<code>\1</code>')

    # Convert bold **text** - must come before italic
    html.gsub!(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')

    # Convert strikethrough ~~text~~
    html.gsub!(/~~([^~]+)~~/, '<del>\1</del>')

    # Convert italic *text* (but not **bold**)
    html.gsub!(/(?<!\*)\*(?!\*)([^*\s][^*]*?[^*\s]|[^*])(?<!\*)\*(?!\*)/, '<em>\1</em>')

    html
  end

  public

  ##
  # Converts markdown to plain text (removes all formatting)
  # Removes "Subject: ..." lines as subject is handled separately by mailer
  def markdown_to_text(text)
    return "" if text.blank?

    text = text.dup

    # Remove Subject line if present (subject is handled separately by CampaignMailer)
    text.gsub!(/^Subject:\s*.+$/i, '')

    # Remove HTML tags if any
    text.gsub!(/<[^>]+>/, '')

    # Remove markdown formatting
    text.gsub!(/\*\*([^*]+)\*\*/, '\1')  # bold
    text.gsub!(/(?<!\*)\*(?!\*)([^*]+?)(?<!\*)\*(?!\*)/, '\1')  # italic
    text.gsub!(/~~([^~]+)~~/, '\1')  # strikethrough
    text.gsub!(/`([^`]+)`/, '\1')  # code
    text.gsub!(/\[([^\]]+)\]\([^\)]+\)/, '\1')  # links
    text.gsub!(/^>\s+/, '')  # blockquotes
    text.gsub!(/^[\-\*]\s+/, '')  # bullet points

    # Clean up multiple blank lines
    text.gsub!(/\n\n\n+/, "\n\n")

    text.strip
  end
end
