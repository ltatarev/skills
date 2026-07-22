#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds a WidgetKit app-extension target to an Xcode project.
#
# Copy into `ios/scripts/add_widget_target.rb`, edit the CONFIG block, and run:
#
#   cd ios && bundle exec ruby scripts/add_widget_target.rb
#
# Idempotent: a project that already has the target is left alone, so this is
# safe to re-run after a `pod install`, a merge, or a project regeneration.
#
# The `xcodeproj` gem comes in with CocoaPods — no extra dependency.

require 'xcodeproj'

# ── CONFIG ────────────────────────────────────────────────────────────────────
APP_TARGET = 'MyApp'                     # the RN app target, as named in Xcode
WIDGET_TARGET = 'MyAppWidget'            # also the folder under ios/
WIDGET_DEPLOYMENT_TARGET = '17.0'        # containerBackground/contentMargins are 17+
APP_ENTITLEMENTS = 'MyApp/MyApp.entitlements'
WIDGET_ENTITLEMENTS = 'MyAppWidget/MyAppWidget.entitlements'
WIDGET_FONTS = [].freeze                 # extensions do NOT inherit the app's fonts

# Files compiled into the WIDGET target only, relative to ios/<WIDGET_TARGET>/.
WIDGET_SOURCES = ['MyAppWidget.swift', 'MyAppWidgetBundle.swift'].freeze
# Resources copied into the widget bundle, same relative root.
WIDGET_RESOURCES = ['placeholder.png'].freeze
# Compiled into BOTH targets, relative to ios/Shared/.
SHARED_SOURCES = ['MyAppWidgetStore.swift'].freeze
# The native module — compiled into the APP target only.
BRIDGE_SOURCES = ['MyAppWidgetBridge.swift', 'MyAppWidgetBridge.m'].freeze
# ──────────────────────────────────────────────────────────────────────────────

IOS_DIR = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(IOS_DIR, "#{APP_TARGET}.xcodeproj")

project = Xcodeproj::Project.open(PROJECT_PATH)

app = project.targets.find { |target| target.name == APP_TARGET }
abort("Could not find the #{APP_TARGET} target in #{PROJECT_PATH}") if app.nil?

if project.targets.any? { |target| target.name == WIDGET_TARGET }
  puts "#{WIDGET_TARGET} already exists — nothing to do."
  exit 0
end

app_settings = app.build_configurations.first.build_settings

# Groups mirroring the folders on disk.
def group_at(project, name)
  group = project.main_group.find_subpath(name, true)
  group.set_source_tree('<group>')
  group.set_path(name)
  group
end

# `path` is relative to the group's *real* path on disk, which is not always the
# group's name — the RN template's app group has no path of its own and resolves
# to `ios/`, so its children have to spell out `<AppTarget>/…` themselves.
def file_in(group, path)
  group.files.find { |file| file.path.to_s == path } || group.new_file(path)
end

shared_group = group_at(project, 'Shared')
widget_group = group_at(project, WIDGET_TARGET)
app_group_node = project.main_group.find_subpath(APP_TARGET, true)

shared_files = SHARED_SOURCES.map { |f| file_in(shared_group, f) }
widget_files = WIDGET_SOURCES.map { |f| file_in(widget_group, f) }
resource_files = WIDGET_RESOURCES.map { |f| file_in(widget_group, f) }
bridge_files = BRIDGE_SOURCES.map { |f| file_in(app_group_node, "#{APP_TARGET}/#{f}") }

# A path that does not resolve to a real file compiles to an opaque
# "Build input file cannot be found" much later, in Xcode rather than here.
(shared_files + widget_files + resource_files + bridge_files).each do |file|
  next if File.exist?(file.real_path)

  abort("Expected #{file.real_path} to exist — check the group paths in this script.")
end

widget = project.new_target(
  :app_extension, WIDGET_TARGET, :ios, WIDGET_DEPLOYMENT_TARGET, nil, :swift
)

widget.add_file_references(widget_files + shared_files)

# Extensions do not inherit the app's fonts — Font.custom silently falls back to
# the system font if the .otf is not in the widget's own resources phase.
font_refs = project.files.select do |file|
  WIDGET_FONTS.include?(File.basename(file.path.to_s))
end
widget.add_resources(font_refs + resource_files)

# The bridge and the shared store compile into the app as well — the app is the
# only writer of the shared container.
app.add_file_references(bridge_files + shared_files)

widget.build_configurations.each do |config|
  config.build_settings.merge!(
    'CODE_SIGN_ENTITLEMENTS' => WIDGET_ENTITLEMENTS,
    'CODE_SIGN_STYLE' => app_settings['CODE_SIGN_STYLE'] || 'Automatic',
    'CURRENT_PROJECT_VERSION' => app_settings['CURRENT_PROJECT_VERSION'] || '1',
    'DEVELOPMENT_TEAM' => app_settings['DEVELOPMENT_TEAM'],
    'ENABLE_PREVIEWS' => 'YES',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => "#{WIDGET_TARGET}/Info.plist",
    'IPHONEOS_DEPLOYMENT_TARGET' => WIDGET_DEPLOYMENT_TARGET,
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
    ],
    'MARKETING_VERSION' => app_settings['MARKETING_VERSION'] || '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{app_settings['PRODUCT_BUNDLE_IDENTIFIER']}.widget",
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_VERSION' => app_settings['SWIFT_VERSION'] || '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
  )
  config.build_settings.compact!
end

# The app carries the entitlement too, or its side of the group is unreadable.
app.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = APP_ENTITLEMENTS
end

embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(widget)

project.save

puts "Added #{WIDGET_TARGET} " \
     "(#{widget.build_configurations.first.build_settings['PRODUCT_BUNDLE_IDENTIFIER']})."
