// Mock implementation for package_info_plus plugin
import 'package:mockito/mockito.dart';

class MockPackageInfo extends Mock {
  String get appName => 'CloudToLocalLLM';
  String get packageName => 'com.cloudtolocalllm.app';
  String get version => '3.6.1';
  String get buildNumber => '202506192205';
}
