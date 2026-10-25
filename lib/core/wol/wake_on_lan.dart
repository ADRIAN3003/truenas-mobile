import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The default for a UDP magic packet; 7 is the other one in use.
const defaultWolPort = 9;

/// Reaches every device on the local network.
const defaultWolBroadcast = '255.255.255.255';

/// Wake-on-LAN settings of one saved server: which network card to wake and
/// where to send the magic packet.
class WakeOnLanSettings {
  const WakeOnLanSettings({
    required this.mac,
    this.broadcast = defaultWolBroadcast,
    this.port = defaultWolPort,
  });

  factory WakeOnLanSettings.fromJson(Map<String, dynamic> json) {
    final port = json['port'];
    final broadcast = (json['broadcast'] as String?)?.trim();
    return WakeOnLanSettings(
      mac: normalizeMac(json['mac'] as String? ?? '') ?? '',
      broadcast: broadcast == null || broadcast.isEmpty
          ? defaultWolBroadcast
          : broadcast,
      port: port is int && isValidPort(port) ? port : defaultWolPort,
    );
  }

  /// The card's MAC address as `AA:BB:CC:DD:EE:FF`.
  final String mac;

  /// Where the packet goes: a broadcast address such as `192.168.1.255`, the
  /// NAS's own address (for a router that forwards it) or a host name.
  final String broadcast;
  final int port;

  Map<String, dynamic> toJson() => {
    'mac': mac,
    'broadcast': broadcast,
    'port': port,
  };

  @override
  bool operator ==(Object other) =>
      other is WakeOnLanSettings &&
      other.mac == mac &&
      other.broadcast == broadcast &&
      other.port == port;

  @override
  int get hashCode => Object.hash(mac, broadcast, port);
}

bool isValidPort(int port) => port >= 1 && port <= 65535;

/// [input] as `AA:BB:CC:DD:EE:FF`, or null when it is not a MAC address.
/// Colons, dashes, dots and spaces between the digits are all accepted
/// (`aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff`, `aabbccddeeff`).
String? normalizeMac(String input) {
  final hex = input.trim().replaceAll(RegExp(r'[\s:.\-]'), '');
  if (!RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(hex)) return null;
  final upper = hex.toUpperCase();
  return [for (var i = 0; i < 12; i += 2) upper.substring(i, i + 2)].join(':');
}

/// The magic packet for [mac]: six 0xFF bytes, then the MAC sixteen times.
Uint8List magicPacket(String mac) {
  final normalized = normalizeMac(mac);
  if (normalized == null) throw FormatException('Not a MAC address', mac);
  final bytes = [
    for (final h in normalized.split(':')) int.parse(h, radix: 16),
  ];
  return Uint8List.fromList([
    ...List.filled(6, 0xFF),
    for (var i = 0; i < 16; i++) ...bytes,
  ]);
}

/// Sends magic packets. A seam so tests do not touch the network.
abstract class WakeOnLanSender {
  Future<void> wake(WakeOnLanSettings settings);
}

class UdpWakeOnLanSender implements WakeOnLanSender {
  const UdpWakeOnLanSender({this.repeats = 3});

  /// UDP broadcast on wifi gets lost now and then, and a second packet to a
  /// machine that is already waking up does nothing.
  final int repeats;

  @override
  Future<void> wake(WakeOnLanSettings settings) async {
    final packet = magicPacket(settings.mac);
    final target =
        InternetAddress.tryParse(settings.broadcast) ??
        (await InternetAddress.lookup(
          settings.broadcast,
          type: InternetAddressType.IPv4,
        )).first;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      for (var i = 0; i < repeats; i++) {
        if (socket.send(packet, target, settings.port) != packet.length) {
          throw const SocketException('The magic packet was not sent');
        }
        if (i < repeats - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    } finally {
      socket.close();
    }
  }
}

final wakeOnLanSenderProvider = Provider<WakeOnLanSender>(
  (ref) => const UdpWakeOnLanSender(),
);
