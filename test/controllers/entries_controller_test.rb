require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "redirects a signed-out visitor to the login page" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end

  test "index lists the current user's entries" do
    get root_path
    assert_response :success
    assert_match entries(:one).transcript, response.body
  end

  test "index does not show another user's entries" do
    other_users_entry = users(:two).entries.create!(transcript: "someone else's private thought")
    get root_path
    assert_no_match other_users_entry.transcript, response.body
  end

  test "index filters by search query" do
    get root_path, params: { q: "stressful" }
    assert_match entries(:two).transcript, response.body
    assert_no_match entries(:one).transcript, response.body
  end

  test "index filters by tag" do
    get root_path, params: { tag: "work" }
    assert_match entries(:two).transcript, response.body
  end

  test "create saves a typed entry" do
    assert_difference("users(:one).entries.count", 1) do
      post entries_path, params: { transcript: "a brand new typed entry" }
    end
    assert_redirected_to root_path
    assert_equal "a brand new typed entry", users(:one).entries.order(:created_at).last.transcript
  end

  test "update toggles the partner sharing flag" do
    entry = entries(:one)
    patch entry_path(entry), params: { shareable_with_partner: "true" }
    assert entry.reload.shareable_with_partner
  end

  test "update edits the transcript and tags" do
    entry = entries(:one)
    patch entry_path(entry), params: { transcript: "an edited transcript", tags: "one, two" }
    entry.reload
    assert_equal "an edited transcript", entry.transcript
    assert_equal %w[one two], entry.tags
  end

  test "cannot update another user's entry" do
    other_users_entry = users(:two).entries.create!(transcript: "not yours")
    patch entry_path(other_users_entry), params: { transcript: "hijacked" }
    assert_response :not_found
    assert_equal "not yours", other_users_entry.reload.transcript
  end

  test "destroy removes the entry" do
    entry = entries(:one)
    assert_difference("users(:one).entries.count", -1) do
      delete entry_path(entry)
    end
    assert_redirected_to root_path
  end
end
