# encoding: utf-8
# frozen_string_literal: true

Bundler.require :default, :development

require 'sprockets/railtie'
require 'fileutils'

class PugRailsTest < Test::Unit::TestCase
  def test_registration
    app = create_rails_application
    app.initialize!

    if app.assets.respond_to?(:transformers)
      assert app.assets.transformers.fetch('text/x-pug').fetch('application/javascript+function') == Pug::Sprockets::Transformer
      assert app.assets.transformers.fetch('text/x-jade').fetch('application/javascript+function') == Jade::Sprockets::Transformer
    end

    if app.assets.respond_to?(:engines)
      assert app.assets.engines.fetch('.pug') == Pug::Sprockets::Transformer
      assert app.assets.engines.fetch('.jade') == Jade::Sprockets::Transformer
    end

    assert app.assets.paths.include?(File.expand_path('../../vendor/assets/javascripts', __FILE__))
    assert_includes app.config.assets.precompile, 'pug/runtime.js'
    assert_includes app.config.assets.precompile, 'jade/runtime.js'
  end

  def test_compilation
    app = create_rails_application
    app.initialize!
    task = create_sprockets_task(app)
    task.instance_exec { manifest.compile(assets) }

    assert_equal File.read(File.expand_path('../fixtures/javascripts/application.js.expected', __FILE__)).squish, \
                 app.assets['application.js'].to_s.squish
  end

  def setup
    super
    clear_tmp
    clear_logs
  end

  def teardown
    super
    clear_tmp
    if defined?(Rails) && Rails.respond_to?(:application=)
      Rails.application = nil
    end
  end

private
  def create_rails_application
    Class.new(Rails::Application) do
      config.eager_load                 = false
      config.assets.enabled             = true
      config.assets.gzip                = false
      config.assets.paths               = [Rails.root.join('test/fixtures/javascripts').to_s]
      config.assets.precompile          = %w[ application.js ]
      config.paths['public']            = [Rails.root.join('tmp').to_s]
      config.active_support.deprecation = :stderr
      config.pug.compile_debug          = false
      config.jade.compile_debug         = false
      config.pug.pretty                 = false
      config.jade.pretty                = false
    end
  end

  def create_sprockets_task(app)
    require 'sprockets/version' # Fix for sprockets 2.x

    if Sprockets::VERSION.start_with?('2')
      require 'rake/sprocketstask'
      Rake::SprocketsTask.new do |t|
        t.environment = app.assets
        t.output      = "#{app.config.paths['public'].to_a[0]}#{app.config.assets.prefix}"
        t.assets      = app.config.assets.precompile
      end
    else
      require 'sprockets/rails/task'
      Sprockets::Rails::Task.new(app)
    end
  end

  def clear_tmp
    FileUtils.rm_rf(File.expand_path('../../tmp', __FILE__))
  end

  def clear_logs
    FileUtils.rm_rf(File.expand_path('../../log', __FILE__))
  end
end
