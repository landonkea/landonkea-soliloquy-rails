class User < ApplicationRecord
  # has_secure_password gives us bcrypt password hashing/checking for free -- generated
  # by `bin/rails generate authentication`, not written by hand.
  has_secure_password
  # Every browser login creates a Session row (see authentication.rb) -- destroying a
  # user should take their sessions with them rather than leaving orphaned rows behind.
  has_many :sessions, dependent: :destroy

  # This is a single-user journal, but the data model still ties every entry/snapshot/
  # report to a real user id rather than assuming "there's only ever one row" --
  # dependent: :destroy means deleting a user's account also removes everything they
  # wrote, instead of leaving orphaned journal entries behind with no owner.
  has_many :entries, dependent: :destroy
  has_many :analysis_snapshots, dependent: :destroy
  has_many :saved_reports, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # The database already enforces this with a unique index (see the CreateUsers
  # migration), but that alone would surface a duplicate sign-up attempt as a raw
  # database error. This model-level check catches it first, so
  # RegistrationsController can show a normal, friendly validation error on the form
  # instead of a 500.
  validates :email_address, presence: true, uniqueness: true
end
