import 'server_instance.dart';

/// The `defaultServerId` setting for "open no server at start".
const noDefaultServer = '';

/// The server to open when the app starts: the one the user chose
/// ([chosen], an id), none when they chose [noDefaultServer], and otherwise a
/// single saved server, since there is nothing else to pick.
ServerInstance? defaultServer(List<ServerInstance> servers, String? chosen) {
  if (chosen == noDefaultServer) return null;
  for (final server in servers) {
    if (server.id == chosen) return server;
  }
  return servers.length == 1 ? servers.single : null;
}
