import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CastDevice {
  final String id;
  final String friendlyName;
  final String? modelName;
  final String? manufacturer;
  final String location;
  final String? controlUrl;

  const CastDevice({
    required this.id,
    required this.friendlyName,
    this.modelName,
    this.manufacturer,
    required this.location,
    this.controlUrl,
  });
}

class CastService {
  static final CastService _instance = CastService._internal();
  factory CastService() => _instance;
  CastService._internal();

  RawDatagramSocket? _socket;
  final List<CastDevice> _discoveredDevices = [];
  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  List<CastDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Start SSDP discovery for DLNA / UPnP Media Renderers
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 6)}) async {
    if (_isScanning) return;
    _isScanning = true;
    _discoveredDevices.clear();
    _devicesController.add([]);

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
      _socket?.broadcastEnabled = true;
      _socket?.multicastHops = 4;

      final multicastAddress = InternetAddress('239.255.255.250');
      const multicastPort = 1900;

      // Listen for incoming SSDP responses
      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data, allowMalformed: true);
            _processSsdpResponse(response);
          }
        }
      });

      // Send SSDP M-SEARCH requests for MediaRenderer & all UPnP devices
      final searches = [
        'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 3\r\n'
            'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n',
        'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 3\r\n'
            'ST: ssdp:all\r\n\r\n',
      ];

      for (final search in searches) {
        final data = utf8.encode(search);
        _socket?.send(data, multicastAddress, multicastPort);
      }

      // Re-send after 1.5 seconds to catch delayed devices
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isScanning && _socket != null) {
          for (final search in searches) {
            final data = utf8.encode(search);
            _socket?.send(data, multicastAddress, multicastPort);
          }
        }
      });

      // Stop after timeout
      Future.delayed(timeout, () {
        stopDiscovery();
      });
    } catch (_) {
      stopDiscovery();
    }
  }

  void stopDiscovery() {
    _isScanning = false;
    try {
      _socket?.close();
      _socket = null;
    } catch (_) {}
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }

  Future<void> _processSsdpResponse(String response) async {
    final lines = response.split('\r\n');
    String? location;

    for (final line in lines) {
      if (line.toUpperCase().startsWith('LOCATION:')) {
        location = line.substring(9).trim();
        break;
      }
    }

    if (location == null || location.isEmpty) return;

    // Check if already processed
    if (_discoveredDevices.any((d) => d.location == location)) return;

    try {
      final res = await http.get(Uri.parse(location)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final body = res.body;

        // Parse friendly name
        final nameMatch = RegExp(r'<friendlyName>(.*?)</friendlyName>', dotAll: true).firstMatch(body);
        final friendlyName = nameMatch?.group(1)?.trim();

        // Parse model name
        final modelMatch = RegExp(r'<modelName>(.*?)</modelName>', dotAll: true).firstMatch(body);
        final modelName = modelMatch?.group(1)?.trim();

        // Parse manufacturer
        final manuMatch = RegExp(r'<manufacturer>(.*?)</manufacturer>', dotAll: true).firstMatch(body);
        final manufacturer = manuMatch?.group(1)?.trim();

        // Check for AVTransport service control URL
        String? controlUrl;
        if (body.contains('urn:schemas-upnp-org:service:AVTransport:1') ||
            body.contains('AVTransport')) {
          final controlMatch = RegExp(
            r'<serviceType>[^<]*AVTransport[^<]*</serviceType>.*?<controlURL>(.*?)</controlURL>',
            dotAll: true,
          ).firstMatch(body);
          if (controlMatch != null) {
            final rawCtrl = controlMatch.group(1)?.trim() ?? '';
            if (rawCtrl.startsWith('http://') || rawCtrl.startsWith('https://')) {
              controlUrl = rawCtrl;
            } else {
              final uri = Uri.parse(location);
              final prefix = rawCtrl.startsWith('/') ? '' : '/';
              controlUrl = '${uri.scheme}://${uri.host}:${uri.port}$prefix$rawCtrl';
            }
          }
        }

        if (friendlyName != null && friendlyName.isNotEmpty) {
          final device = CastDevice(
            id: location,
            friendlyName: friendlyName,
            modelName: modelName,
            manufacturer: manufacturer,
            location: location,
            controlUrl: controlUrl,
          );

          if (!_discoveredDevices.any((d) => d.location == location || d.friendlyName == friendlyName)) {
            _discoveredDevices.add(device);
            _devicesController.add(List.unmodifiable(_discoveredDevices));
          }
        }
      }
    } catch (_) {}
  }

  /// Send stream URL to DLNA device via UPnP AVTransport
  Future<bool> castToDlnaDevice(CastDevice device, String videoUrl, {String? title}) async {
    if (device.controlUrl == null) return false;

    try {
      final safeTitle = title ?? 'AniDash Stream';
      final escapedUrl = videoUrl.replaceAll('&', '&amp;');

      // SOAP SetAVTransportURI XML
      final setUriSoap = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>$escapedUrl</CurrentURI>
      <CurrentURIMetaData>&lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;&lt;item id="1" parentID="0" restricted="1"&gt;&lt;dc:title&gt;$safeTitle&lt;/dc:title&gt;&lt;res protocolInfo="http-get:*:video/*:*"&gt;$escapedUrl&lt;/res&gt;&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;</CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';

      final setUriRes = await http.post(
        Uri.parse(device.controlUrl!),
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
        },
        body: setUriSoap,
      ).timeout(const Duration(seconds: 5));

      if (setUriRes.statusCode == 200) {
        // Send Play Action
        final playSoap = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>''';

        await http.post(
          Uri.parse(device.controlUrl!),
          headers: {
            'Content-Type': 'text/xml; charset="utf-8"',
            'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Play"',
          },
          body: playSoap,
        ).timeout(const Duration(seconds: 5));

        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Launch Web Video Caster app
  Future<bool> launchWebVideoCaster(String videoUrl, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse('wvc-x-callback://open?url=${Uri.encodeComponent(videoUrl)}&secure_uri=true');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      final intentUri = Uri.parse(
        'intent:$videoUrl#Intent;action=android.intent.action.VIEW;'
        'package=com.instantbits.cast.webvideo;'
        'type=video/*;end',
      );
      return await launchUrl(intentUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Launch BubbleUPnP app
  Future<bool> launchBubbleUPnP(String videoUrl) async {
    try {
      final intentUri = Uri.parse(
        'intent:$videoUrl#Intent;action=android.intent.action.VIEW;'
        'package=com.bubblesoft.android.bubbleupnp;'
        'type=video/*;end',
      );
      return await launchUrl(intentUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Launch VLC for Android
  Future<bool> launchVlc(String videoUrl) async {
    try {
      final intentUri = Uri.parse(
        'intent:$videoUrl#Intent;action=android.intent.action.VIEW;'
        'package=org.videolan.vlc;'
        'type=video/*;end',
      );
      return await launchUrl(intentUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Launch Generic External Player / Cast Intent
  Future<bool> launchGenericPlayer(String videoUrl) async {
    try {
      final uri = Uri.parse(videoUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Copy stream URL to clipboard
  Future<void> copyStreamUrl(String videoUrl) async {
    await Clipboard.setData(ClipboardData(text: videoUrl));
  }
}
