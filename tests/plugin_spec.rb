# frozen_string_literal: true

require 'json'

# This plugin's tests, run with `trmnlp test` (add `--report report` for a page of every screen it drew).
# Docs: https://github.com/usetrmnl/trmnlp#testing-plugins
RSpec.describe 'Pollen Information Austria' do
  def self.forecast(name) = JSON.parse(File.read(File.join(__dir__, 'fixtures', "forecast_#{name}.json")))

  # Demo values only: a public landmark (Stephansdom, Vienna) and a dummy key; every request is mocked.
  let(:base_fields) do
    { 'apikey' => 'demo', 'country' => 'AT', 'language' => 'de', 'location' => '48.208493,16.373118',
      'min_severity' => '1', 'pollen_filter' => '', 'show_allergy_risk' => 'true' }
  end

  {
    # A real answer from November: one pollen type at level 1, everything else at 0.
    'a quiet autumn day' => [forecast('autumn'), {}],
    # The same answer with nothing at or above the minimum severity: the "no pollen" screen.
    'a day without pollen above the minimum' => [forecast('autumn'), { 'min_severity' => '2' }],
    # The default minimum (1) with a filter that matches nothing: "no pollen" without a level.
    'a day without the filtered pollen' => [forecast('autumn'), { 'pollen_filter' => 'Birke, Gräser' }],
    # A spring answer: many pollen types at levels 1-3 and a high allergy risk.
    'a busy spring day' => [forecast('spring'), {}]
  }.each do |day, (answer, fields)|
    context "on #{day}" do
      let(:mocks) { { 'https://www.polleninformation.at/api/forecast/public*' => { json: answer } } }
      let(:custom_fields) { base_fields.merge(fields) }

      # Every view on TRMNL's devices, a failing API and every select option and switch, checked for page errors
      # and leaked values.
      it_behaves_like 'a publishable recipe'

      # The shared group draws each language in the full view only; the smaller views have less room for the
      # longer translations and the "no pollen" message.
      if day.include?('without pollen')
        %w[half_horizontal half_vertical quadrant].product(TRMNLP::Testing.option_field_values['language']).each do |view, lang|
          it "keeps the #{view} view inside the screen on og_png in #{lang}" do
            fields = custom_fields.merge('language' => lang, 'pollen_filter' => 'Birke, Gräser', 'min_severity' => '1')
            expect(trmnl.render(view:, device: 'og_png', mocks:, custom_fields: fields))
              .to have_no_overflow.and(have_no_overlapping_text).and(have_no_leaked_text)
          end
        end
      end

      %w[full half_horizontal half_vertical quadrant].product(
        [{ device: 'og_png' }, { device: 'v2' }, { device: 'v2', orientation: :portrait }], %w[true false]
      ).each do |view, screen, risk|
        it "keeps the #{view} view inside the screen on #{TRMNLP::Testing.screen_name(screen)} " \
           "with the allergy risk #{risk == 'true' ? 'shown' : 'hidden'}" do
          fields = custom_fields.merge('show_allergy_risk' => risk)
          expect(trmnl.render(view:, **screen, mocks:, custom_fields: fields)).to have_no_overflow
        end
      end
    end
  end
end
