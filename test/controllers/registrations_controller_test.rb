require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new is reachable without being signed in" do
    get new_registration_path
    assert_response :success
  end

  test "create signs up a new user and logs them straight in" do
    assert_difference("User.count", 1) do
      post registration_path, params: {
        user: { email_address: "new-journaler@example.com", password: "a-real-password", password_confirmation: "a-real-password" }
      }
    end
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create re-renders the form when the password confirmation does not match" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: { email_address: "mismatch@example.com", password: "one-password", password_confirmation: "different" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create rejects a duplicate email address" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: { email_address: users(:one).email_address, password: "a-real-password", password_confirmation: "a-real-password" }
      }
    end
    assert_response :unprocessable_entity
  end
end
