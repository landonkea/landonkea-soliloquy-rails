require "test_helper"

class MqttBridgeServiceTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "handle_write saves a brand new entry from a plain text payload" do
    outcome = MqttBridgeService.handle_write({ text: "said out loud" }.to_json, user: @user)
    assert outcome.entry.present?
    assert_not outcome.appended
    assert_equal "said out loud", outcome.entry.transcript
  end

  test "handle_write with type=append appends to a recent same-speaker entry" do
    MqttBridgeService.handle_write({ text: "first part", speaker: "Landon" }.to_json, user: @user)
    outcome = MqttBridgeService.handle_write({ text: "second part", speaker: "Landon", type: "append" }.to_json, user: @user)

    assert outcome.appended
    assert_equal "first part second part", outcome.entry.transcript
  end

  test "handle_write rejects a payload with no usable text" do
    outcome = MqttBridgeService.handle_write({ text: "   " }.to_json, user: @user)
    assert_nil outcome.entry
    assert_match(/no usable/, outcome.error)
  end

  test "handle_write rejects non-JSON payloads without raising" do
    outcome = MqttBridgeService.handle_write("not json at all", user: @user)
    assert_nil outcome.entry
    assert_match(/valid JSON/, outcome.error)
  end

  test "handle_query returns a summary for entries in the requested window" do
    entries(:one) # fixture entries already exist for this user
    fake_result = AnalysisResult.new(entry_count: 2, total_word_count: 10, summary: "a real summary", mood_notes: "steady", key_topics: [ "work" ])
    analyzer = Object.new
    analyzer.define_singleton_method(:analyze) { |*_args, **_kwargs| fake_result }

    response = MqttBridgeService.handle_query({ days: 7 }.to_json, user: @user, analyzer: analyzer)
    assert_equal "a real summary", response[:summary]
    assert_equal 7, response[:days]
  end

  test "handle_query returns nil when there are no entries to analyze" do
    empty_user = users(:two)
    empty_user.entries.destroy_all
    response = MqttBridgeService.handle_query({ days: 7 }.to_json, user: empty_user, analyzer: AnalyzerService.free_analyzer)
    assert_nil response
  end
end
