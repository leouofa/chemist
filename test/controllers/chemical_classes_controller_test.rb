# frozen_string_literal: true

require "test_helper"

class ChemicalClassesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateChemicalClassesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateChemicalClassesJob) do
      post populate_chemical_classes_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Chemical Classes...", response.body
  end

  test "populate enqueues PopulateChemicalClassesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateChemicalClassesJob) do
      post populate_chemical_classes_url
    end

    assert_redirected_to root_url
  end
end
