# frozen_string_literal: true

require 'json'

# This plugin's tests, run with `trmnlp test` (add `--report report` for a page of every screen it drew).
# Docs: https://github.com/usetrmnl/trmnlp#testing-plugins
RSpec.describe 'Pollen Information Austria' do
  def self.forecast(name) = JSON.parse(File.read(File.join(__dir__, 'fixtures', "forecast_#{name}.json")))

  # Demo values only: a public landmark (Stephansdom, Vienna) and a dummy key; every request is mocked.
  let(:custom_fields) do
    { 'apikey' => 'demo', 'country' => 'AT', 'language' => 'de', 'location' => '48.208493,16.373118',
      'min_severity' => '1', 'pollen_filter' => '' }
  end

  {
    # A real answer from November: one pollen type at level 1, everything else at 0.
    'a quiet autumn day' => forecast('autumn'),
    # A spring answer: many pollen types at levels 1-3 and a high allergy risk.
    'a busy spring day' => forecast('spring')
  }.each do |season, answer|
    context "on #{season}" do
      let(:mocks) { { 'https://www.polleninformation.at/api/forecast/public*' => { json: answer } } }

      # Every view on TRMNL's devices, a failing API and every select option, checked for page errors and leaked values.
      it_behaves_like 'a publishable recipe'

      %w[full half_horizontal half_vertical quadrant].product(
        [{ device: 'og_png' }, { device: 'v2' }, { device: 'v2', orientation: :portrait }]
      ).each do |view, screen|
        it "keeps the #{view} view inside the screen on #{TRMNLP::Testing.screen_name(screen)}" do
          expect(trmnl.render(view:, **screen, mocks:, custom_fields:)).to have_no_overflow
        end
      end
    end
  end
end
