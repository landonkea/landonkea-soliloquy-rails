# ───────────────────────────────────────────────────────────────────
# ReportRenderer, turns a ReportContent into any of the four export formats
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's report.py -- text/markdown/html render as plain string
# building (Ruby's ERB::Util for HTML-escaping instead of Python's html.escape), and
# PDF uses Prawn, the Ruby equivalent of the original's fpdf2.
class ReportRenderer
  FORMATS = %w[text markdown html pdf].freeze

  def initialize(content)
    @content = content
  end

  def self.render(content, format)
    renderer = new(content)
    case format
    when "text" then renderer.to_text
    when "markdown" then renderer.to_markdown
    when "html" then renderer.to_html
    when "pdf" then renderer.to_pdf
    else raise ArgumentError, "Unknown report format #{format.inspect}, must be one of #{FORMATS}"
    end
  end

  def to_text
    lines = [
      @content.title,
      "#{@content.entry_count} entries, #{@content.total_word_count} words",
      "",
      "Summary", "-------", @content.summary, "",
      "Mood", "----", @content.mood_notes, "",
      "Key topics", "----------", @content.topics_line, "",
      "Entries", "-------"
    ]
    @content.entries.each { |created_at, transcript| lines << "[#{created_at}] #{transcript}" }
    "#{lines.join("\n")}\n"
  end

  def to_markdown
    lines = [
      "# #{@content.title}", "",
      "**#{@content.entry_count} entries, #{@content.total_word_count} words**", "",
      "## Summary", "", @content.summary, "",
      "## Mood", "", @content.mood_notes, "",
      "## Key topics", "", @content.topics_line, "",
      "## Entries", ""
    ]
    @content.entries.each { |created_at, transcript| lines << "- **#{created_at}** -- #{transcript}" }
    "#{lines.join("\n")}\n"
  end

  def to_html
    # ERB::Util.html_escape is the same "never trust user text going into HTML"
    # protection the original's html.escape gave it -- a transcript could contain
    # anything, including characters that would otherwise break the page.
    escape = ->(text) { ERB::Util.html_escape(text) }
    entries_html = @content.entries.map { |created_at, transcript|
      "<li><strong>#{escape.call(created_at)}</strong> -- #{escape.call(transcript)}</li>"
    }.join("\n")
    entries_html = "<li>(none)</li>" if @content.entries.empty?

    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <title>#{escape.call(@content.title)}</title>
      <style>
        body { font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; color: #222; }
        h1 { font-size: 1.4rem; }
        h2 { font-size: 1.1rem; margin-top: 1.5rem; }
        li { margin-bottom: 0.5rem; }
      </style>
      </head>
      <body>
      <h1>#{escape.call(@content.title)}</h1>
      <p><strong>#{@content.entry_count} entries, #{@content.total_word_count} words</strong></p>
      <h2>Summary</h2>
      <p>#{escape.call(@content.summary)}</p>
      <h2>Mood</h2>
      <p>#{escape.call(@content.mood_notes)}</p>
      <h2>Key topics</h2>
      <p>#{escape.call(@content.topics_line)}</p>
      <h2>Entries</h2>
      <ul>
      #{entries_html}
      </ul>
      </body>
      </html>
    HTML
  end

  def to_pdf
    require "prawn"
    pdf = Prawn::Document.new

    # A tiny local helper so every heading/paragraph below is one line instead of
    # repeating font-size/style setup -- Prawn's own equivalent of the original's
    # nested `line()` helper inside format_pdf.
    write = ->(text, size:, bold: false) {
      pdf.font_size(size) { pdf.text(text, style: bold ? :bold : :normal) }
    }

    write.call(@content.title, size: 16, bold: true)
    write.call("#{@content.entry_count} entries, #{@content.total_word_count} words", size: 11)
    pdf.move_down 8

    section = ->(heading, body) {
      write.call(heading, size: 13, bold: true)
      write.call(body, size: 11)
      pdf.move_down 4
    }

    section.call("Summary", @content.summary)
    section.call("Mood", @content.mood_notes)
    section.call("Key topics", @content.topics_line)

    write.call("Entries", size: 13, bold: true)
    @content.entries.each do |created_at, transcript|
      write.call("[#{created_at}] #{transcript}", size: 9)
      pdf.move_down 2
    end

    pdf.render
  end
end
