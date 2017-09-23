require "test_helper"
require "webmock/minitest"

class PublisherStatementGeneratorTest < ActiveJob::TestCase
  test "when offline returns a dummy link with accurate query params" do
    prev_offline = Rails.application.secrets[:api_eyeshade_offline]
    Rails.application.secrets[:api_eyeshade_offline] = true

    publisher = publishers(:verified)
    result = PublisherStatementGenerator.new(publisher: publisher, statement_period: :past_7_days).perform

    assert_equal "/publishers/home?starting=#{(Date.today - 7).iso8601}&ending=#{Date.today.iso8601}", result

    Rails.application.secrets[:api_eyeshade_offline] = prev_offline
  end

  test "when online returns the reportURL returned by eyeshade" do
    prev_offline = Rails.application.secrets[:api_eyeshade_offline]
    Rails.application.secrets[:api_eyeshade_offline] = false

    stub_request(:get, /v1\/publishers\/verified\.org\/statement/).
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Faraday v0.9.2'}).
        to_return(status: 200, body: "{\"reportURL\":\"example.com/fake-report\"}", headers: {})

    publisher = publishers(:verified)
    result = PublisherStatementGenerator.new(publisher: publisher, statement_period: :all).perform
    assert_equal "example.com/fake-report", result

    Rails.application.secrets[:api_eyeshade_offline] = prev_offline
  end

  test "generates starting / ending query params" do
    publisher = publishers(:verified)

    # TODO: Consider testing with TimeCop

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :past_7_days)
    assert_equal "?starting=#{(Date.today - 7).iso8601}&ending=#{Date.today.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :past_30_days)
    assert_equal "?starting=#{(Date.today - 30).iso8601}&ending=#{Date.today.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :this_month)
    assert_equal "?starting=#{(Date.today.beginning_of_month).iso8601}&ending=#{Date.today.end_of_month.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :last_month)
    assert_equal "?starting=#{((Date.today - 1.month).beginning_of_month).iso8601}&ending=#{(Date.today - 1.month).end_of_month.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :this_year)
    assert_equal "?starting=#{Date.today.beginning_of_year.iso8601}&ending=#{Date.today.end_of_year.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :last_year)
    assert_equal "?starting=#{((Date.today - 1.year).beginning_of_year).iso8601}&ending=#{(Date.today - 1.year).end_of_year.iso8601}", generator.query_params

    generator = PublisherStatementGenerator.new(publisher: publisher, statement_period: :all)
    assert_nil generator.query_params
  end
end