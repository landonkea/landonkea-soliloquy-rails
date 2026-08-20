# ───────────────────────────────────────────────────────────────────
# TranscriptCleanupService, a plain rule-based readability pass
# ───────────────────────────────────────────────────────────────────
# Direct port of the original's transcript_cleanup.py. Raw transcription output is one
# unbroken run of text with sparse punctuation -- fine for the AI analyzer, which reads
# for meaning rather than style, but rough to read back on the Entries page. This is
# deliberately NOT another AI call: it's deterministic, free, instant, and easy to
# test, because "make this readable" only needs capitalization, terminal punctuation,
# and paragraph breaks, not a model. Only ever applied to transcribed (audio/video)
# entries -- a typed entry is already however its author chose to format it, and
# shouldn't get silently rewritten.
class TranscriptCleanupService
  # How many sentences get grouped into one paragraph before starting a new one --
  # matches the original's _SENTENCES_PER_PARAGRAPH constant exactly.
  SENTENCES_PER_PARAGRAPH = 4

  # A sentence boundary is any run of whitespace that comes right after a ".", "!", or
  # "?" -- this is what splits the wall of text into individual sentences to work with.
  SENTENCE_BOUNDARY = /(?<=[.!?])\s+/

  # Takes raw transcript text and returns a cleaned-up version with capitalized
  # sentences, terminal punctuation added where missing, and paragraph breaks every
  # few sentences.
  def self.call(text)
    new(text).call
  end

  def initialize(text)
    @text = text
  end

  def call
    # split with no arguments (then re-joined with a single space) collapses any run
    # of whitespace -- including the double spaces and stray newlines transcription
    # sometimes produces -- down to one space each, same as Python's `" ".join(text.split())`.
    collapsed = @text.to_s.split.join(" ")
    return collapsed if collapsed.empty?

    sentences = collapsed.split(SENTENCE_BOUNDARY).map(&:strip).reject(&:empty?)
    sentences = sentences.map { |sentence| capitalize_first_letter(sentence) }
    sentences = sentences.map { |sentence| ensure_terminal_punctuation(sentence) }

    # each_slice groups the flat sentence array into chunks of SENTENCES_PER_PARAGRAPH,
    # and each chunk becomes one paragraph, joined with a blank line between them --
    # the same grouping the original built with a Python range() step.
    paragraphs = sentences.each_slice(SENTENCES_PER_PARAGRAPH).map { |group| group.join(" ") }
    paragraphs.join("\n\n")
  end

  private

  # Uppercases just the very first character, leaving the rest of the sentence
  # untouched (so mid-sentence proper nouns/acronyms aren't mangled).
  def capitalize_first_letter(sentence)
    return sentence if sentence.empty?
    sentence[0].upcase + sentence[1..]
  end

  # Adds a period if the sentence doesn't already end in one of ".", "!", or "?" --
  # transcription often drops trailing punctuation entirely.
  def ensure_terminal_punctuation(sentence)
    return sentence if sentence.empty?
    %w[. ! ?].include?(sentence[-1]) ? sentence : "#{sentence}."
  end
end
