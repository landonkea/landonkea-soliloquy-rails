# A distinguishable subclass of RuntimeError specifically for HTTP 429s, so a caller
# can tell "this provider is temporarily out of quota" apart from other failures, even
# if today every caller treats all failures the same (move on to the next provider).
# Kept in its own file for the same autoloading reason as NoEntriesError above.
module Analyzers
  class RateLimitError < RuntimeError; end
end
