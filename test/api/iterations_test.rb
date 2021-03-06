require_relative '../api_helper'

class ItertaionsApiTest < Minitest::Test
  include Rack::Test::Methods
  include DBCleaner

  def app
    ExercismAPI::App
  end

  def test_latest_iterations_requires_key
    get '/iterations/latest'
    assert_equal 401, last_response.status
  end

  def test_latest_iterations
    alice = User.create(username: 'alice', github_id: 1)

    sub1 = {
      user: alice,
      language: 'go',
      slug: 'one',
      solution: {'oneA.go' => 'CODE1AGO', 'oneB.go' => 'CODE1BGO'},
      state: 'superseded',
      created_at: 10.minutes.ago,
    }
    sub2 = {
      user: alice,
      language: 'go',
      slug: 'two',
      solution: {'two.go' => 'CODE2GO'},
      state: 'superseded',
      created_at: 10.minutes.ago,
    }
    sub3 = {
      user: alice,
      language: 'ruby',
      slug: 'one',
      state: 'pending',
      solution: {'one.rb': 'CODE1RUBY'},
    }
    sub4 = {
      user: alice,
      language: 'ruby',
      slug: 'two',
      state: 'hibernating',
      solution: {'two.rb': 'CODE2RUBY'},
    }
    [sub1, sub2, sub3, sub4].each {|sub| Submission.create(sub)}
    Hack::UpdatesUserExercise.new(alice.id, 'go', 'one').update
    Hack::UpdatesUserExercise.new(alice.id, 'ruby', 'one').update
    Hack::UpdatesUserExercise.new(alice.id, 'ruby', 'two').update

    get '/iterations/latest', {key: alice.key}

    output = last_response.body
    options = {format: :json, :name => 'api_iterations'}
    Approvals.verify(output, options)
  end

  def test_skip_problem
    alice = User.create(username: 'alice', github_id: 1)

    post '/iterations/ruby/one/skip', {key: alice.key}

    exercise = alice.exercises.first
    assert_equal 'ruby', exercise.language
    assert_equal 'one', exercise.slug
    assert_equal 'unstarted', exercise.state
  end

  def test_skip_skipped_problem
    alice = User.create(username: 'alice', github_id: 1)

    post '/iterations/ruby/one/skip', {key: alice.key}
    post '/iterations/ruby/one/skip', {key: alice.key}

    assert_equal 400, last_response.status
    assert last_response.body.include?('already been skipped')
  end

  def test_skip_started_problem
    alice = User.create(username: 'alice', github_id: 1)

    Submission.create(user: alice, language: 'ruby', slug: 'one', code: 'CODE1RB', state: 'pending', filename: 'one.rb')
    Hack::UpdatesUserExercise.new(alice.id, 'ruby', 'one').update

    post '/iterations/ruby/one/skip', {key: alice.key}

    assert_equal 400, last_response.status
    assert last_response.body.include?('already been started')
  end
end
