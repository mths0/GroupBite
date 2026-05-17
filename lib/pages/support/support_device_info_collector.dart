import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SupportDeviceInfoCollector {
  SupportDeviceInfoCollector({DeviceInfoPlugin? deviceInfoPlugin})
    : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfoPlugin;

  Future<Map<String, dynamic>> collect(BuildContext context) async {
    final mediaQuery = MediaQuery.of(context);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final now = DateTime.now();

    final info = <String, dynamic>{
      'capturedAt': now.toIso8601String(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'isWeb': kIsWeb,
      'locale': dispatcher.locale.toLanguageTag(),
      'preferredLocales': dispatcher.locales
          .map((locale) => locale.toLanguageTag())
          .toList(),
      'timeZoneName': now.timeZoneName,
      'timeZoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'screen': _screenInfo(mediaQuery),
      'app': await _appInfo(),
      'device': await _platformDeviceInfo(),
    };

    return info;
  }

  Map<String, dynamic> _screenInfo(MediaQueryData mediaQuery) {
    final size = mediaQuery.size;
    final pixelRatio = mediaQuery.devicePixelRatio;

    return {
      'logicalWidth': size.width,
      'logicalHeight': size.height,
      'physicalWidth': size.width * pixelRatio,
      'physicalHeight': size.height * pixelRatio,
      'devicePixelRatio': pixelRatio,
      'orientation': mediaQuery.orientation.name,
      'textScale': mediaQuery.textScaler.scale(1),
      'platformBrightness': mediaQuery.platformBrightness.name,
      'accessibleNavigation': mediaQuery.accessibleNavigation,
      'boldText': mediaQuery.boldText,
      'disableAnimations': mediaQuery.disableAnimations,
      'highContrast': mediaQuery.highContrast,
      'padding': _edgeInsetsInfo(mediaQuery.padding),
      'viewPadding': _edgeInsetsInfo(mediaQuery.viewPadding),
    };
  }

  Map<String, dynamic> _edgeInsetsInfo(EdgeInsets insets) {
    return {
      'top': insets.top,
      'right': insets.right,
      'bottom': insets.bottom,
      'left': insets.left,
    };
  }

  Future<Map<String, dynamic>> _appInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'installerStore': packageInfo.installerStore,
        'installTime': packageInfo.installTime?.toIso8601String(),
        'updateTime': packageInfo.updateTime?.toIso8601String(),
      };
    } catch (error) {
      return {'error': error.toString()};
    }
  }

  Future<Map<String, dynamic>> _platformDeviceInfo() async {
    try {
      if (kIsWeb) {
        return _webInfo(await _deviceInfoPlugin.webBrowserInfo);
      }

      return switch (defaultTargetPlatform) {
        TargetPlatform.android => _androidInfo(
          await _deviceInfoPlugin.androidInfo,
        ),
        TargetPlatform.iOS => _iosInfo(await _deviceInfoPlugin.iosInfo),
        TargetPlatform.macOS => _macOsInfo(await _deviceInfoPlugin.macOsInfo),
        TargetPlatform.linux => _linuxInfo(await _deviceInfoPlugin.linuxInfo),
        TargetPlatform.windows => _windowsInfo(
          await _deviceInfoPlugin.windowsInfo,
        ),
        TargetPlatform.fuchsia => {'platform': 'fuchsia'},
      };
    } catch (error) {
      return {'error': error.toString()};
    }
  }

  Map<String, dynamic> _androidInfo(AndroidDeviceInfo info) {
    return {
      'platform': 'android',
      'manufacturer': info.manufacturer,
      'brand': info.brand,
      'model': info.model,
      'device': info.device,
      'product': info.product,
      'hardware': info.hardware,
      'androidVersion': info.version.release,
      'sdkInt': info.version.sdkInt,
      'securityPatch': info.version.securityPatch,
      'buildDisplay': info.display,
      'buildType': info.type,
      'buildTags': info.tags,
      'isPhysicalDevice': info.isPhysicalDevice,
      'isLowRamDevice': info.isLowRamDevice,
      'physicalRamMb': info.physicalRamSize,
      'availableRamMb': info.availableRamSize,
      'freeDiskBytes': info.freeDiskSize,
      'totalDiskBytes': info.totalDiskSize,
      'supportedAbis': info.supportedAbis,
    };
  }

  Map<String, dynamic> _iosInfo(IosDeviceInfo info) {
    return {
      'platform': 'ios',
      'systemName': info.systemName,
      'systemVersion': info.systemVersion,
      'model': info.model,
      'modelName': info.modelName,
      'localizedModel': info.localizedModel,
      'machine': info.utsname.machine,
      'isPhysicalDevice': info.isPhysicalDevice,
      'isIOSAppOnMac': info.isiOSAppOnMac,
      'isIOSAppOnVision': info.isiOSAppOnVision,
      'physicalRamMb': info.physicalRamSize,
      'availableRamMb': info.availableRamSize,
      'freeDiskBytes': info.freeDiskSize,
      'totalDiskBytes': info.totalDiskSize,
    };
  }

  Map<String, dynamic> _webInfo(WebBrowserInfo info) {
    return {
      'platform': 'web',
      'browserName': info.browserName.name,
      'appName': info.appName,
      'appVersion': info.appVersion,
      'browserPlatform': info.platform,
      'language': info.language,
      'languages': info.languages,
      'vendor': info.vendor,
      'userAgent': info.userAgent,
      'deviceMemoryGb': info.deviceMemory,
      'hardwareConcurrency': info.hardwareConcurrency,
      'maxTouchPoints': info.maxTouchPoints,
    };
  }

  Map<String, dynamic> _macOsInfo(MacOsDeviceInfo info) {
    return {
      'platform': 'macos',
      'arch': info.arch,
      'model': info.model,
      'modelName': info.modelName,
      'osRelease': info.osRelease,
      'majorVersion': info.majorVersion,
      'minorVersion': info.minorVersion,
      'patchVersion': info.patchVersion,
      'activeCPUs': info.activeCPUs,
      'memorySizeBytes': info.memorySize,
      'cpuFrequencyHz': info.cpuFrequency,
    };
  }

  Map<String, dynamic> _linuxInfo(LinuxDeviceInfo info) {
    return {
      'platform': 'linux',
      'name': info.name,
      'version': info.version,
      'id': info.id,
      'idLike': info.idLike,
      'versionCodename': info.versionCodename,
      'versionId': info.versionId,
      'prettyName': info.prettyName,
      'buildId': info.buildId,
      'variant': info.variant,
      'variantId': info.variantId,
    };
  }

  Map<String, dynamic> _windowsInfo(WindowsDeviceInfo info) {
    return {
      'platform': 'windows',
      'numberOfCores': info.numberOfCores,
      'systemMemoryMb': info.systemMemoryInMegabytes,
      'majorVersion': info.majorVersion,
      'minorVersion': info.minorVersion,
      'buildNumber': info.buildNumber,
      'displayVersion': info.displayVersion,
      'editionId': info.editionId,
      'productName': info.productName,
      'releaseId': info.releaseId,
    };
  }
}
