#
# Be sure to run `pod lib lint DinSupport.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DinSupport'
  s.version          = '0.0.2'
  s.summary          = 'DinSupport'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = "Base framework used in Dinsafe"

  s.homepage         = 'https://gitlab.sca.im/wen.yongyang/dinsupport.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ios' => 'ios@dinsafe.com' }
  s.source           = { :git => 'https://gitlab.sca.im/iOS/DinSupport', :tag => s.version.to_s }

  s.swift_version = "5.0"
  s.ios.deployment_target = '11.0'

  s.source_files = ['DinSupport/DinSupport.h', 'DinSupport/Source/**/*']

  s.dependency 'CryptoSwift'
  s.dependency 'CocoaAsyncSocket', '7.6.5'
  s.dependency 'SSZipArchive', '2.4.3'

end
