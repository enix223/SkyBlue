#
# Be sure to run `pod lib lint SkyBlue.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SkyBlue'
  s.version          = '0.2.1'
  s.summary          = 'Yet another Bluetooth library for iOS'
  s.description      = <<-DESC
To build an easy to use iOS BLE library
                       DESC

  s.homepage         = 'https://github.com/enix223/SkyBlue'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'enix223' => 'enix223@163.com' }
  s.source           = { :git => 'https://github.com/enix223/SkyBlue.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'SkyBlue/Classes/**/*'
end
