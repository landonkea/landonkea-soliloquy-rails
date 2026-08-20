require "test_helper"

class MoodChartServiceTest < ActiveSupport::TestCase
  Snapshot = Struct.new(:mood_score)

  test "returns nil with fewer than two scored snapshots" do
    assert_nil MoodChartService.render([])
    assert_nil MoodChartService.render([ Snapshot.new(5) ])
  end

  test "returns nil when every snapshot has no mood_score" do
    assert_nil MoodChartService.render([ Snapshot.new(nil), Snapshot.new(nil) ])
  end

  test "renders a real SVG polyline for two or more scored snapshots" do
    svg = MoodChartService.render([ Snapshot.new(3), Snapshot.new(8) ])
    assert_match(/<svg/, svg)
    assert_match(/<polyline/, svg)
    assert_equal 2, svg.scan("<circle").size
  end

  test "skips unscored points but still renders the scored ones" do
    svg = MoodChartService.render([ Snapshot.new(3), Snapshot.new(nil), Snapshot.new(8) ])
    assert_equal 2, svg.scan("<circle").size
  end
end
