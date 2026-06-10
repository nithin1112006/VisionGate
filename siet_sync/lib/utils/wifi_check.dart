import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config/college_ip_config.dart';
import 'vpn_check.dart';

/// Runtime settings loaded from server
class AppSettings {
  static bool allowAnyNetwork = false;
  static String collegeSSID = '';
  static bool enforceGeoFence = true;
  static bool enforceAppGeoFence = true;
  static bool enforceVpnBlocking = true;
  static bool _isLoaded = false;
  static DateTime? _lastLoaded;
  static const Duration _cacheExpiry = Duration(seconds: 10);

  /// Fetch settings from server
  static Future<void> loadSettings({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) {
      if (_lastLoaded != null &&
          DateTime.now().difference(_lastLoaded!) < _cacheExpiry) {
        return;
      }
    }

    try {
      final url = '${CollegeIPConfig.defaultURL}/settings/allow_any_network';
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response(
              '{"allow_any_network": false, "college_ssid": "", "enforce_geo_fence": true, "enforce_app_geo_fence": true, "enforce_vpn_blocking": true}',
              200,
            ),
          );

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          response.body.isNotEmpty ? jsonDecode(response.body) : {},
        );
        allowAnyNetwork = data['allow_any_network'] ?? false;
        collegeSSID = data['college_ssid'] ?? '';
        enforceGeoFence = data['enforce_geo_fence'] ?? true;
        enforceAppGeoFence = data['enforce_app_geo_fence'] ?? true;
        enforceVpnBlocking = data['enforce_vpn_blocking'] ?? true;
      }
    } catch (e) {
      if (!_isLoaded) {
        allowAnyNetwork = false;
        collegeSSID = '';
        enforceGeoFence = true;
        enforceAppGeoFence = true;
      }
    }
    _isLoaded = true;
    _lastLoaded = DateTime.now();
  }

  /// Force refresh settings from server
  static Future<void> refreshSettings() async {
    await loadSettings(forceRefresh: true);
  }

  /// Parse JSON safely - kept for backward compatibility if called elsewhere
  static Map<String, dynamic> parseJson(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (e) {
      // Ignore parse errors - fallback to default values will be used
    }
    return {};
  }

  /// Reset for testing
  static void reset() {
    _isLoaded = false;
    _lastLoaded = null;
    allowAnyNetwork = false;
    collegeSSID = '';
    enforceGeoFence = true;
    enforceAppGeoFence = true;
    enforceVpnBlocking = true;
  }
}

/// WiFi Checker Utility
class WifiChecker {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Check if device is connected to WiFi
  static Future<bool> isWifiConnected() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result == ConnectivityResult.wifi;
    } catch (e) {
      return false;
    }
  }

  /// Get current WiFi SSID
  static Future<String?> getCurrentWifiSSID() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      if (wifiName == null || wifiName.isEmpty) return null;
      // Clean up: remove quotes, whitespace, <unknown ssid>
      final cleaned = wifiName.replaceAll('"', '').replaceAll("'", '').trim();
      if (cleaned.isEmpty || cleaned.toLowerCase() == '<unknown ssid>') {
        return null;
      }
      return cleaned;
    } catch (e) {
      return null;
    }
  }

  /// Check if connected to allowed college WiFi
  static Future<bool> isOnCollegeWifi() async {
    await AppSettings.loadSettings();

    // If allow_any_network is true (toggle OFF), allow from anywhere
    if (AppSettings.allowAnyNetwork) {
      return true;
    }

    final requiredSSID = _getRequiredSSID();

    final isWifi = await isWifiConnected();
    if (!isWifi) {
      print('[WIFI] Not connected to WiFi');
      return false;
    }

    final ssid = await getCurrentWifiSSID();
    print('[WIFI] Current SSID: "$ssid"');

    if (ssid == null || ssid.isEmpty) {
      return false;
    }

    // Case-insensitive comparison
    final matches = ssid.toLowerCase() == requiredSSID.toLowerCase();
    print('[WIFI] SSID match: $matches (checking "$ssid" == "$requiredSSID")');
    return matches;
  }

  /// Get WiFi status message for display
  static Future<String> getWifiStatusMessage() async {
    await AppSettings.loadSettings();

    if (AppSettings.allowAnyNetwork) {
      return 'Network check disabled. You can mark attendance from any network.';
    }

    final requiredSSID = _getRequiredSSID();
    final isWifi = await isWifiConnected();

    if (!isWifi) {
      return 'Not connected to WiFi. Please connect to $requiredSSID';
    }

    final ssid = await getCurrentWifiSSID();
    if (ssid != null) {
      if (ssid.toLowerCase() == requiredSSID.toLowerCase()) {
        return 'Connected to $ssid (Allowed network)';
      } else {
        return 'Connected to $ssid (Not the required network: $requiredSSID)';
      }
    }

    return 'Connected to WiFi, but SSID detection is unavailable. Please enable location and try again.';
  }

  /// Validate and return error message if not on college WiFi
  static Future<String?> validateCollegeWifi() async {
    await AppSettings.loadSettings();

    // Check VPN first
    final vpnError = await VpnChecker.validateVpnStatus();
    if (vpnError != null) {
      return vpnError;
    }

    if (AppSettings.allowAnyNetwork) {
      return null;
    }

    final isOnCollege = await isOnCollegeWifi();

    if (!isOnCollege) {
      if (!await isWifiConnected()) {
        return 'Please connect to a WiFi network to mark attendance.';
      }

      final ssid = await getCurrentWifiSSID();
      if (ssid == null || ssid.isEmpty) {
        return 'Unable to detect WiFi SSID. Please enable location and try again.';
      }
      final requiredSSID = _getRequiredSSID();
      if (ssid.toLowerCase() != requiredSSID.toLowerCase()) {
        return 'You are connected to "$ssid". Please connect to "$requiredSSID" to mark attendance.';
      }

      return 'Unable to verify WiFi connection. Please try again.';
    }

    return null;
  }

  static String _getRequiredSSID() {
    final configured = AppSettings.collegeSSID.trim();
    if (configured.isNotEmpty) return configured;
    return 'LifeatSriShakthi';
  }
}
