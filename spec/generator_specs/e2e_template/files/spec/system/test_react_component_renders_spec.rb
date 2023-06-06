require "rails_helper"

RSpec.describe "home/index", type: :system, js: true do
  before do
    driven_by(:selenium_headless)
  end

  it "renders the App component" do
    visit "home/index"

    expect(page.body).to match "App component"
  end
end
