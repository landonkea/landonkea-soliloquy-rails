require "test_helper"

class ReportRendererTest < ActiveSupport::TestCase
  setup do
    @content = ReportContent.new(
      days: 7, audience: "self", entry_count: 2, total_word_count: 20,
      summary: "A steady week.", mood_notes: "Mood held up.", key_topics: [ "work", "family" ],
      entries: [ [ "2026-08-18T10:00:00+00:00", "First entry." ], [ "2026-08-19T10:00:00+00:00", "Second entry." ] ]
    )
  end

  test "renders plain text with every section" do
    text = ReportRenderer.render(@content, "text")
    assert_match(/Summary/, text)
    assert_match(/A steady week\./, text)
    assert_match(/First entry\./, text)
  end

  test "renders markdown headings" do
    markdown = ReportRenderer.render(@content, "markdown")
    assert_match(/^## Summary/, markdown)
    assert_match(/\*\*2 entries, 20 words\*\*/, markdown)
  end

  test "renders HTML with escaped entry content" do
    content = ReportContent.new(
      days: 1, audience: "self", entry_count: 1, total_word_count: 3,
      summary: "s", mood_notes: "m", key_topics: [],
      entries: [ [ "2026-08-20T00:00:00+00:00", "<script>alert(1)</script>" ] ]
    )
    html = ReportRenderer.render(content, "html")
    assert_match(/&lt;script&gt;/, html)
    assert_no_match(/<script>alert/, html)
  end

  test "renders a real, non-empty PDF" do
    pdf_bytes = ReportRenderer.render(@content, "pdf")
    assert pdf_bytes.start_with?("%PDF")
  end

  test "raises for an unknown format" do
    assert_raises(ArgumentError) { ReportRenderer.render(@content, "yaml") }
  end
end
