FROM ruby:3.3.6
WORKDIR /gem
COPY Gemfile spinel_accel.gemspec ./
COPY lib ./lib
RUN bundle install
COPY . .
ENV SPINEL_ACCEL_TEST_BUNDLES=/gem/tmp/native-test-bundles/bundles.json
ENV SPINEL_ACCEL_TEST_CACHE=/gem/tmp/native-cache
CMD ["bundle", "exec", "rake", "test"]
