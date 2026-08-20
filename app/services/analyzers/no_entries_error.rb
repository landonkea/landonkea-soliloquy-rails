# Raised when asked to analyze an empty list of entries -- there's nothing honest an
# analyzer can say about zero entries, so this is a caller mistake to catch and
# message clearly, never papered over with a placeholder result. Kept in its own file
# (rather than tucked inside base_analyzer.rb) so Rails' autoloader can find this
# constant directly, even from code that references it without ever touching
# BaseAnalyzer first.
module Analyzers
  class NoEntriesError < StandardError; end
end
