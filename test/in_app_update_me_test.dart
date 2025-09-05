import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update_me/in_app_update_me.dart';
import 'package:in_app_update_me/in_app_update_me_platform_interface.dart';
import 'package:in_app_update_me/in_app_update_me_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInAppUpdateMePlatform
    with MockPlatformInterfaceMixin
    implements InAppUpdateMePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<UpdateInfo?> checkForUpdate({
    bool useStore = true,
    String? updateUrl,
    String? currentVersion,
  }) => Future.value(UpdateInfo(
    updateAvailable: true,
    immediateUpdateAllowed: true,
    flexibleUpdateAllowed: true,
  ));

  @override
  Future<bool> startFlexibleUpdate({String? downloadUrl}) => Future.value(true);

  @override
  Future<bool> startImmediateUpdate() => Future.value(true);

  @override
  Future<bool> completeFlexibleUpdate() => Future.value(true);

  @override
  Future<bool> downloadAndInstallUpdate(String downloadUrl) => Future.value(true);

  @override
  Future<bool> isUpdateAvailable() => Future.value(true);

  @override
  void setUpdateListener(UpdateListener listener) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final InAppUpdateMePlatform initialPlatform = InAppUpdateMePlatform.instance;

  test('$MethodChannelInAppUpdateMe is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelInAppUpdateMe>());
  });

  test('getPlatformVersion', () async {
    InAppUpdateMe inAppUpdateMePlugin = InAppUpdateMe();
    MockInAppUpdateMePlatform fakePlatform = MockInAppUpdateMePlatform();
    InAppUpdateMePlatform.instance = fakePlatform;

    expect(await inAppUpdateMePlugin.getPlatformVersion(), '42');
  });

  test('checkForUpdate', () async {
    InAppUpdateMe inAppUpdateMePlugin = InAppUpdateMe();
    MockInAppUpdateMePlatform fakePlatform = MockInAppUpdateMePlatform();
    InAppUpdateMePlatform.instance = fakePlatform;

    final updateInfo = await inAppUpdateMePlugin.checkForUpdate();
    expect(updateInfo?.updateAvailable, true);
    expect(updateInfo?.immediateUpdateAllowed, true);
    expect(updateInfo?.flexibleUpdateAllowed, true);
  });

  test('startFlexibleUpdate', () async {
    InAppUpdateMe inAppUpdateMePlugin = InAppUpdateMe();
    MockInAppUpdateMePlatform fakePlatform = MockInAppUpdateMePlatform();
    InAppUpdateMePlatform.instance = fakePlatform;

    expect(await inAppUpdateMePlugin.startFlexibleUpdate(), true);
  });

  test('startImmediateUpdate', () async {
    InAppUpdateMe inAppUpdateMePlugin = InAppUpdateMe();
    MockInAppUpdateMePlatform fakePlatform = MockInAppUpdateMePlatform();
    InAppUpdateMePlatform.instance = fakePlatform;

    expect(await inAppUpdateMePlugin.startImmediateUpdate(), true);
  });

  test('downloadAndInstallUpdate', () async {
    InAppUpdateMe inAppUpdateMePlugin = InAppUpdateMe();
    MockInAppUpdateMePlatform fakePlatform = MockInAppUpdateMePlatform();
    InAppUpdateMePlatform.instance = fakePlatform;

    expect(await inAppUpdateMePlugin.downloadAndInstallUpdate('test_url'), true);
  });

  test('UpdateConfig creation', () {
    const config = UpdateConfig(
      useStore: true,
      forceUpdate: false,
      checkInterval: Duration(hours: 24),
    );

    expect(config.useStore, true);
    expect(config.forceUpdate, false);
    expect(config.checkInterval, const Duration(hours: 24));
  });

  test('DirectUpdateConfig creation', () {
    const config = DirectUpdateConfig(
      serverUrl: 'https://test.com',
      versionEndpoint: '/version',
      downloadEndpoint: '/download',
    );

    expect(config.serverUrl, 'https://test.com');
    expect(config.versionCheckUrl, 'https://test.com/version');
    expect(config.downloadUrl, 'https://test.com/download');
    expect(config.useStore, false);
  });
}