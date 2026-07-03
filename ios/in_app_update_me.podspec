Pod::Spec.new do |s|
  s.name             = 'in_app_update_me'
  s.version          = '1.2.0'
  s.summary          = 'A comprehensive Flutter plugin for in-app updates supporting both Android and iOS.'
  s.description      = <<-DESC
A Flutter plugin that provides in-app update capabilities for both Android and iOS platforms with direct update functionality and force update handling.
                       DESC
  s.homepage         = 'https://github.com/atishpaul/in_app_update_me'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flenco' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # Matches the minimum deployment target Flutter itself has generated for
  # new projects since the 3.x template refresh; App Store submissions built
  # with current Xcode already require this floor in practice.
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end